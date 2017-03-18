#!/bin/bash
: ${particles_per_core:=5}
: ${example_num:=10}
: ${example_py:=SRWLIB_Example$example_num.py}
t() {
    local c=$1
    local w=$(( $c - 1 ))
    if (( $w == 0 )); then
        w=1
    fi
    p=$(( $w * $particles_per_core ))
    export p
    perl -pi -e 's/^(nMacroElec =)\s*\d+/$1 $ENV{p}/' "$example_py"
    local op=()
    if (( $c > 1 )); then
	op=( mpirun -n $c )
    fi
    local s=$(date +%s)
    "${op[@]}" python $example_py >& /dev/null
    s=$(( $(date +%s) - $s ))
    local ppc=$(( $p / $w ))
    echo "${c}c ${p}p ${s}s $(( ($s + ($ppc / 2)) / $ppc ))s/p/w"
}

main() {
    if [[ ! -r $example_py ]]; then
        curl -L -O -s -S https://raw.githubusercontent.com/radiasoft/SRW-light/master/env/work/srw_python/"$example_py"
    fi
    mkdir -p "data_example_$example_num"
    local i
    for i in "$@"; do
	t "$i"
    done
}
main "$@"
