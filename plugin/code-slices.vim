"if exists( "g:loaded_code_slices" )
    "finish
"endif
"let g:loaded_code_slices = 1

fun! s:show_slices() "{{{
    try
        call s:verify_not_called_from_slices()
    catch /CALLED FROM SLICES/
        echohl WarningMsg | echo 'Recursive slices not allowed' | echohl None
        return
    endtry

    call s:create_window_if_needed()
    call s:mappings_for_code_slices_window()
endfunction "}}}

fun! s:verify_not_called_from_slices() "{{{
    if &ft =~? 'slices$'
        throw 'CALLED FROM SLICES'
    endif
endfunction "}}}

fun! s:mappings_for_code_slices_window() "{{{
    nnoremap <silent><buffer> q :bw<CR>
    nnoremap <buffer> u <Nop>
    nnoremap <buffer> p <Nop>
    nnoremap <buffer> P <Nop>
    "Insert slice with <CR>
    nnoremap <buffer> <CR> :call <SID>insert_current_slice()<CR>
    "Insert slice and return to slices window
    nnoremap <buffer> <S-CR> :call <SID>insert_current_slice() \|
                \ call <SID>go_to_slices_window()<CR>
    augroup slices
        au!
        au InsertEnter <buffer> normal 
    augroup END
endfunction "}}}

fun! s:load_slices(ft)
    set modifiable
    %d
    let files = findfile('slices/' . a:ft . '.slices', &rtp, -1)
    for filename in files
        call append(line('$'), readfile(filename))
    endfor
    1
    1d
    set nomodifiable
endfunction

fun! s:create_window_if_needed() "{{{
    let current_window = bufwinnr('^slices$')
    let working_window = expand('%')
    let type = &ft
    if current_window < 0
        keepalt vertical belowrigh new slices
    else
        call s:go_to_slices_window()
    endif
    vertical resize 45
    let b:last_window = working_window
    call s:load_slices(type)
    set ft=
    exe "set ft=" . type . ".slices"
    setlocal wrap buftype=nowrite bufhidden=wipe nobuflisted noswapfile number
endfunction "}}}

fun! s:go_to_slices_window() "{{{
    let current_window = bufwinnr('^slices$')
    silent! execute current_window.'wincmd w'
endfunction "}}}

fun! s:insert_current_slice() "{{{
    let bounds = s:find_slice_bounds()
    if !has_key(bounds, 'slice_start')
        echohl WarningMsg | echo 'Not a slice' | echohl None
        return
    endif

    let lines = s:get_lines_from_bounds(bounds)
    let destination = bufwinnr(b:last_window)
    if destination == -1
        echohl WarningMsg | echo 'Window not reacheable' | echohl None
        return
    endif
    execute destination . 'wincmd w'

    call s:update_and_format_buffer(lines)
endfunction "}}}

fun! s:update_and_format_buffer(lines) "{{{
    let working_lines = a:lines
    "Preserve indentation
    "0 or more spaces not followed by a space and match all chars in line
    "and substitute with 0 or more matched spaces. Also match empty lines
    let line_spaces = substitute(getline(line('.')), '\v(^[[:space:]]*)([[:space:]])@!.*', '\1', '')
    for line_index in range(len(working_lines))
        let working_lines[line_index] = substitute(working_lines[line_index], '^', line_spaces, '')
    endfor

    if getline(line('.')) =~? '\v^[[:space:]]+$'
        call setline(line('.'), working_lines[0])
        let working_lines = working_lines[1:]
    endif
    let line_nr = line('.')
    for line in working_lines
        call append(line_nr, line)
        let line_nr += 1
    endfor
    call setpos('.', [0, line_nr, len(getline(line_nr)), 0])
endfunction "}}}

fun! s:get_lines_from_bounds(bounds) "{{{
    let lines = []
    let first_line = getline(a:bounds['slice_start'])
    let pattern = '\v^[[:space:]]{' . &ts . '}'
    let correct_lines = 0

    if first_line =~? '\v^[[:space:]]' && &et == 0
        if &et == 0
            let pattern = '\v^\t'
        endif
        let correct_lines = 1
    endif

    for line in range(a:bounds['slice_start'], a:bounds['slice_end'])
        let corrected_line = getline(line)
        if correct_lines == 1
            let corrected_line = substitute(getline(line), pattern, '', '')
        endif
        call add(lines, corrected_line)
    endfor
    return lines
endfunction "}}}

fun! s:find_slice_bounds() "{{{
    let offset = &tabstop
    if &et == 0
        let offset = 1
    endif

    let ret_dict = {}
    if getline('.') =~? '\v^(Slice|Group)'
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
        endif
        if getline(line_nr) =~? '\v^$'
            let count_empty_lines += 1
            if count_empty_lines > 1
                return line_nr
            endif
        endif
    endfor
    return line('$')
endfunction "}}}

command! ShowSlices call s:show_slices()

