use std::error::Error;
use std::fs;
use std::path::Path;

use celox::{Simulator, SimulatorBuilder};
use struo_celox::ecp5_simulator;
use struo_frontend_veryl::analyze_and_lower;
use struo_synth::synthesize;
use struo_target_ecp5::{MappingOptions, map_to_ecp5_with_options};

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

    let design = analyze_and_lower(&source, "ecp5_evn_blinky", "Top")?;
    let synthesized = synthesize(&design)?;
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

    Ok(())
}
