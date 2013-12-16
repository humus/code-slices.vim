"if exists( "g:loaded_code_slices" )
    "finish
"endif
"let g:loaded_code_slices = 1

fun! s:show_slices() "{{{
    call s:create_window_if_needed()
    call s:mappings_for_code_slices_window()
endfunction "}}}

fun! s:mappings_for_code_slices_window() "{{{
    "Insert slice with <CR>
    nnoremap <buffer> <CR> :call <SID>insert_current_slice()<CR>
    nnoremap <buffer> <S-CR> :call <SID>insert_current_slice() \| call <SID>go_to_slices_window()<CR>
    nnoremap q :bd<CR>
endfunction "}}}

fun! s:load_slices(ft)
    let filename = findfile('slices/' . a:ft . '.slices', &rtp)
    let lines = readfile(filename)
    call append(0, lines)
    $d
endfunction

fun! s:create_window_if_needed() "{{{
    let current_window = bufwinnr('^code_slices$')
    let type = &ft
    let b:alternate = expand('#')
    let b:view = winsaveview()
    if current_window < 0
        silent! execute 'vertical belowrigh new code_slices'
    else
        call s:go_to_slices_window()
    endif
    vertical resize 45
    call s:load_slices(type)
    set ft=
    exe "set ft=" . type . ".slice"
    setlocal wrap buftype=nowrite bufhidden=wipe nobuflisted noswapfile nonumber
endfunction "}}}

fun! s:go_to_slices_window() "{{{
    let current_window = bufwinnr('^code_slices$')
    silent! execute current_window.'wincmd w'
endfunction "}}}

fun! s:insert_current_slice() "{{{
    let bounds = s:find_slice_bounds()
    if !has_key(bounds, 'slice_start')
        echohl WarningMsg | echo 'Not a slice' | echohl None
        return
    endif

    let lines = s:get_lines_from_bounds(bounds)

    let destination = expand('#')
    execute bufwinnr(destination) . 'wincmd w'
    execute 'e ' . b:alternate
    normal 
    call winrestview(b:view)
    let line_nr = line('.')
    for line in lines
        call append(line_nr, line)
        let line_nr += 1
    endfor
endfunction "}}}

fun! s:get_lines_from_bounds(bounds) "{{{
    let lines = []
    let first_line = getline(a:bounds['slice_start'])
    let pattern = '\v^[[:space:]]{' . &ts . '}'

    if first_line =~? '\v[[:space:]]' && &et == 1
        let pattern = '\v^\t'
    endif

    for line in range(a:bounds['slice_start'], a:bounds['slice_end'])
        let corrected_line = substitute(line, pattern, '', '')
        call add(lines, getline(corrected_line))
    endfor
    return lines
endfunction "}}}

fun! s:find_slice_bounds() "{{{
    let offset = &tabstop
    if &et == 0
        let offset = 1
    endif

    let ret_dict = {}
    if getline('.') =~? '\v(Slice|Group)'
        normal za
        return ret_dict
    endif

    let ret_dict['slice_start'] = s:find_slice_start()
    let ret_dict['slice_end'] = s:find_slice_end()
    return ret_dict
endfunction "}}}

fun! s:find_slice_start() "{{{
    for line_nr in range(line('.'), 0, -1)
        if getline(line_nr) =~? '\vSlice'
            return line_nr + 1
            break
        endif
        if getline(line_nr) =~? '\v^Group'
            throw 'BAD_FORMAT: No slice after group'
        endif
    endfor
endfunction "}}}

fun! s:find_slice_end() "{{{
    let count_empty_lines = 0
    for line_nr in range(line('.') + 1, line('$'))
        if getline(line_nr) =~? '\v^(Group|Slice)'
            return line_nr - 1
            break
        endif
        if getline(line_nr) =~? '\v^$'
            let count_empty_lines += 1
            if count_empty_lines > 1
                return line_nr
                break
            endif
        endif
    endfor
    return line('$')
endfunction "}}}

command! ShowSlices call s:show_slices()

