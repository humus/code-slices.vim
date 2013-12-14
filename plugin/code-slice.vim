if exists( "g:loaded_code_slices" )
    finish
endif
let g:loaded_code_slices = 1

fun! s:show_slices() "{{{
    call s:create_window_if_needed()
    call s:mappings_for_code_slices_window()
endfunction "}}}

fun! s:mappings_for_code_slices_window() "{{{
    "Insert slice with <CR>
    nnoremap <CR> :call <SID>insert_current_slice()<CR>
    nnoremap <S-CR> :call <SID>insert_current_slice() \| call <SID>back_to_slices_window()<CR>
endfunction "}}}

fun! s:create_window_if_needed() "{{{
    let current_window = bufwinnr('^code_slices$')
    if current_window < 0
        silent! execute 'vertical belowrigh new code_slices'
    else
        call s:back_to_slices_window()
    endif
    vertical resize 45
    setlocal wrap buftype=nowrite bufhidden=wipe nobuflisted noswapfile nonumber
endfunction "}}}

fun! s:back_to_slices_window() "{{{
    let current_window = bufwinnr('^code_slices$')
    silent! execute current_window.'wincmd w'
endfunction "}}}

fun! s:insert_current_slice() "{{{
    echohl WarningMsg | echo 'TOBEDEFINED' | echohl None
endfunction "}}}

command! ShowSlices call s:show_slices()
