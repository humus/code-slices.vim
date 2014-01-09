fun! SlicesTabMoving(flag) "{{{
    if &ft !~# '\.slices'
        return "\<Tab>"
    endif
    call s:close_when_needed()
    if getline(line('.')) =~# '\v^(Fluent)?Slice.*'
        if b:auto_close_folds
            normal zv
        endif
        let pos = getpos('.')
        call cursor(pos[1]+1, pos[2])
        if b:auto_close_folds
            normal zv
        endif
        return
    endif
    if a:flag == 'b'
        let pos = getpos('.')
        call cursor(pos[1] - 1, 0)
    endif
    let pos = searchpos('\v^(Fluent)?Slice.*$', a:flag)
    if pos[0] == 0
        call cursor([1, 1])
        let pos = searchpos('\v^(Fluent)?Slice.*$', a:flag)
        if pos[0] == 0
            throw 'No Slices'
        endif
        if b:auto_close_folds
            normal za
        endif
    endif
    call setpos('.', pos)
    call SlicesTabMoving(a:flag)
endfunction "}}}

fun! s:close_when_needed() "{{{
    if g:keep_open_unactive_slices == 0 && b:auto_close_folds
        normal! zc
    endif
endfunction "}}}

nnoremap <silent><buffer> <Tab> :call SlicesTabMoving('')<CR>
nnoremap <silent><buffer> <BS> :call SlicesTabMoving('b')<CR>


let b:auto_close_folds=0

