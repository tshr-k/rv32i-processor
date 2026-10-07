package math_pkg;
    // compute $clog2(x) but clamped to [1, infinity)
    function automatic int unsigned min1_clog2(
        input int unsigned x
    );
        return (x == 1) ? 1 : unsigned'($clog2(x));
    endfunction
endpackage
