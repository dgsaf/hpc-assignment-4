#! /usr/bin/env nextflow

// header
version = "0.1"
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
seeds = Channel.of(5, 10)
ncores = Channel.of(1, 2)
input_ch = seeds.combine(ncores)

//input_ch.view()

// find
process find {
  input:
  tuple(val(seed), val(cores)) from input_ch
  path(image) from Channel.fromPath(params.image)
  path(bkg) from Channel.fromPath(params.bkg)
  path(rms) from Channel.fromPath(params.rms)

  exec:
  println "($seed, $cores)"

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
  path(files) from files_ch

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
    nsrc=$(echo "$(cat ${f}  | wc -l)-1" | bc -l)
    echo "${seed},${cores},${nsrc}" >> results.csv
  done
  '''
}

/*
// plot
process plot {
  input:
  path(table) from counted_ch

  output:
  file("*.png") into final_ch

  cpus 4

  script:
  """
  """
}
*/