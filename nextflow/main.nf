#! /usr/bin/env nextflow

// header
version = "1.0"
date = "2021-06-14"
author = "Tom Ross"

// initialise logging
log.info """\
         PHYS4004 workflow assignment
         ============================
         version      : ${version} - ${date}
         author       : ${author}
         --
         run as       : ${workflow.commandLine}
         config files : ${workflow.configFiles}
         container    : ${workflow.containerEngine}:${workflow.container}
         """
         .stripIndent()

// input channel
seeds = Channel.of(5 .. 95).filter{it % 5 == 0}
ncores = Channel.of(1, 2, 4, 7)
input_ch = seeds.combine(ncores)

// find
process find {
  input:
  path(image) from params.image
  path(bkg) from params.bkg
  path(rms) from params.rms
  tuple(val(seed), val(cores)) from input_ch

  output:
  file("*.csv") into files_ch
  cpus "${cores}"

  script:
  """
  aegean ${image} --background=${bkg} --noise=${rms} --table=out.csv \
  --seedclip=${seed} --cores=${cores}

  mv out_comp.csv table_${seed}_${cores}.csv
  """
}

// count
process count {
  input:
  path(files) from files_ch.collect()

  output:
  file("results.csv") into counted_ch

  container = ""

  shell:
  '''
  echo "seed,ncores,nsrc" > results.csv
  files=($(ls table*.csv))
  for f in ${files[@]}; do
    seed_cores=($(echo ${f} | tr '_.' ' ' | awk '{print $2 " " $3}'))
    seed=${seed_cores[0]}
    cores=${seed_cores[1]}
    nsrc=$(echo "$(cat ${f} | wc -l) - 1" | bc -l)
    echo "${seed},${cores},${nsrc}" >> results.csv
  done
  '''
}

// duplicate counted channel for both plot methods
counted_ch.into{counted_for_ch; counted_xargs_ch}

// plot (for loop)
process plot_for {
  input:
  path(table) from counted_for_ch

  output:
  file("*.png") into final_for_ch

  cpus 4

  shell:
  '''
  ncores_set=$(awk -F, '{if (NR != 1) {print $2}}' !{table} | sort | uniq)

  for ncores in $ncores_set ; do
    python !{projectDir}/plot_completeness.py \
    --infile !{table} --outfile plot_for_${ncores}.png --cores $ncores
  done
  '''
}

// plot (with xargs)
process plot_xargs {
  input:
  path(table) from counted_xargs_ch

  output:
  file("*.png") into final_xargs_ch

  cpus 4

  shell:
  '''
  ncores_set=$(awk -F, '{if (NR != 1) {print $2}}' !{table} | sort | uniq)

  printf '%s ' $ncores_set | xargs -n1 -P4 -I ncores -d ' ' \
  python !{projectDir}/plot_completeness.py \
  --infile !{table} --outfile plot_xargs_ncores.png --cores ncores
  '''
}
