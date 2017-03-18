: ${particles_per_core:=5}
t() {
    local c=$1
    local w=$(( $c - 1 ))
    if (( $w == 0 )); then
        w=1    
    fi
    p=$(( $w * $particles_per_core ))
    export p
    perl -pi -e 's/^(nMacroElec =)\s*\d+/$1 $ENV{p}/' SRWLIB_Example10.py
    local op=()
    if (( $c > 1 )); then
	op=( mpirun -n $c )
    fi
    local s=$(date +%s)
    "${op[@]}" python SRWLIB_Example10.py >& /dev/null
    s=$(( $(date +%s) - $s ))
    echo "${c}c ${p}p ${s}s $(( $s / ( $p / $w ) ))s/p/w"
}

main() {
    mkdir -p data_example_10
    local i
    for i in "$@"; do
	t "$i"
    done
}
main "$@"
