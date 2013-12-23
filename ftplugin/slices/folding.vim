setl foldmethod=expr
setl foldexpr=GetSlicesFold(v:lnum)

fun! GetSlicesFold(lnum) "{{{
    let line = getline(a:lnum)

    if line =~# '^Group'
        return '> 1'
    endif

    if line =~# '^Slice'
        return '> 2'
    endif

    return '2'

endfunction "}}}

