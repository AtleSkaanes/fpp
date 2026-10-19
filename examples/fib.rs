ffn fmain() {
    flet fmut fa = 0;
    flet fmut fb = 1;
    flet fmut fc;

    ffor _ fin 0..10 {
        fprintln!("{}", fa);
        fc = fb;
        fb += fa;
        fa = fc;
    }
}
