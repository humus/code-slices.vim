setl foldmethod=expr
setl foldexpr=GetSlicesFold(v:lnum)

fun! GetSlicesFold(lnum) "{{{
    let line = getline(a:lnum)

    if line =~# '\v^Group'
        return '> 1'
    endif

    if line =~# '\v^(Fluent)?Slice'
        return '> 2'
    endif

    return '2'

endfunction "}}}

