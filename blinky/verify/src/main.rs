use std::error::Error;
use std::fs::{self, File};
use std::io::{BufReader, BufWriter, Write};
use std::path::Path;

use celox::{Simulator, SimulatorBuilder};
use struo_celox::ecp5_simulator;
use struo_synth::synthesize;
use struo_target_ecp5::{MappingOptions, map_to_ecp5_with_options};
use texo_cli::{ecp5_checkpoint, load_veryl_project};
use texo_flow::{Ecp5FlowOptions, Evidence, Gate, implement_struo_ecp5};
use texo_struo::import_ecp5;
use texo_target_ecp5::{parse_lpf, read_architecture};

const SAMPLE_CYCLES: [usize; 5] = [0, 65_535, 65_536, 131_072, 196_608];

fn expected_led(counter: usize) -> u8 {
    ((counter >> 16) as u8).reverse_bits()
}

fn verify_simulator(simulator: &mut Simulator, label: &str) -> Result<(), Box<dyn Error>> {
    let clock = simulator.event("clk");
    let reset = simulator.signal("btn");
    let led = simulator.signal("led");

    simulator.modify(|io| io.set(reset, 0_u8))?;
    simulator.tick(clock)?;
    if simulator.get(led) != 0_u8.into() {
        return Err(format!("{label}: LEDs are not zero during reset").into());
    }

    simulator.modify(|io| io.set(reset, 1_u8))?;
    let mut cycle = 0_usize;
    for sample in SAMPLE_CYCLES {
        while cycle < sample {
            simulator.tick(clock)?;
            cycle += 1;
        }
        let expected = expected_led(cycle);
        if simulator.get(led) != expected.into() {
            return Err(format!(
                "{label}: LED mismatch at cycle {cycle}: expected 0x{expected:02x}"
            )
            .into());
        }
    }

    println!(
        "{label}: passed through {} cycles",
        SAMPLE_CYCLES.last().unwrap()
    );

    Ok(())
}

fn main() -> Result<(), Box<dyn Error>> {
    let project = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let source = fs::read_to_string(project.join("src/Top.veryl"))?;

    let mut rtl = SimulatorBuilder::new(&source, "Top").build_native()?;
    verify_simulator(&mut rtl, "Celox RTL simulation")?;

    let loaded = load_veryl_project(project, Some("Top"))?;
    let synthesized = synthesize(&loaded.design)?;
    let mapped = map_to_ecp5_with_options(
        &synthesized.netlist,
        MappingOptions {
            timing_goal_mhz: 12,
            ..MappingOptions::default()
        },
    )?;
    if !mapped.retiming().equivalence_signed_off {
        return Err("Struo mapping equivalence was not signed off".into());
    }

    let mut post_map = ecp5_simulator(&mapped)?.build_native()?;
    let post_map_clock = post_map.event("clk");
    let post_map_reset = post_map.signal("btn");
    let post_map_led = post_map.signal("led");
    post_map.modify(|io| io.set(post_map_reset, 0_u8))?;
    post_map.tick(post_map_clock)?;
    if post_map.get(post_map_led) != 0_u8.into() {
        return Err("Celox post-map simulation: LEDs are not zero during reset".into());
    }

    post_map.modify(|io| io.set(post_map_reset, 1_u8))?;
    let mut cycle = 0_usize;
    for sample in SAMPLE_CYCLES {
        while cycle < sample {
            post_map.tick(post_map_clock)?;
            cycle += 1;
        }
        let expected = expected_led(cycle);
        if post_map.get(post_map_led) != expected.into() {
            return Err(format!(
                "Celox post-map simulation: LED mismatch at cycle {cycle}: expected 0x{expected:02x}"
            )
            .into());
        }
    }
    println!(
        "Celox post-map simulation: passed through {} cycles",
        SAMPLE_CYCLES.last().unwrap()
    );
    println!(
        "Struo synthesis: {} nodes, {} registers, {} ECP5 cells; equivalence passed",
        synthesized.netlist.nodes().len(),
        synthesized.netlist.registers().len(),
        mapped.cells().len()
    );

    fs::write(
        project.join("build/Top.struo.json"),
        mapped.to_nextpnr_json()?,
    )?;
    let architecture_path = project.join("build/LFE5UM5G-85F.json");
    let architecture = read_architecture(BufReader::new(File::open(&architecture_path)?))?;
    let constraints = parse_lpf(File::open(project.join("lfe5um5g-85f-evn.lpf"))?)?;
    let imported = import_ecp5(&mapped)?;
    let mut evidence = Evidence::new();
    evidence.record(Gate::SynthesisEquivalence);
    evidence.record(Gate::PostMapSimulation);
    let implemented = implement_struo_ecp5(
        &imported,
        &architecture,
        Ecp5FlowOptions {
            speed_grade: Some("8"),
            package: Some("CABGA381"),
            lpf: Some(&constraints),
            ..Ecp5FlowOptions::default()
        },
        &mut evidence,
    )?;
    if !implemented.timing.met_timing() {
        return Err("Texo implementation did not meet timing".into());
    }

    let checkpoint = ecp5_checkpoint("Top", &implemented, &architecture, "CABGA381", &evidence);
    let mut checkpoint_file = BufWriter::new(File::create(
        project.join("build/Top.texo.checkpoint.json"),
    )?);
    serde_json::to_writer_pretty(&mut checkpoint_file, &checkpoint)?;
    checkpoint_file.write_all(b"\n")?;
    checkpoint_file.flush()?;

    println!(
        "Texo PnR: {} cells, {} nets, {} PIPs; WNS {} ps, WHS {} ps; timing passed",
        implemented.design.cells().len(),
        implemented.implementation.routes.len(),
        implemented.implementation.total_pips,
        implemented.timing.worst_slack_ps.unwrap_or_default(),
        implemented.timing.worst_hold_slack_ps.unwrap_or_default(),
    );

    Ok(())
}
