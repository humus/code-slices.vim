"if exists( "g:loaded_code_slices" )
    "finish
"endif
"let g:loaded_code_slices = 1

" variable used in a little hack to auto-close slices window, since slices
" window is directly related to buffer which exec the ShowSlices commnand at
" least for now the less error-prone alternative is to close that window
let g:ignore_next_buf_enter = 0

if !exists( "g:slices_prefered_path" )
    let g:slices_prefered_path = expand('$HOME') . '/vimfiles/'
endif
if !exists("g:keep_open_unactive_slices")
    let g:keep_open_unactive_slices=0
endif

fun! s:show_slices() "{{{
    try
        call s:verify_not_called_from_slices()
    catch /CALLED FROM SLICES/
        echohl WarningMsg | echo 'Recursive slices not allowed' | echohl None
        return
    endtry
    call s:prepare_to_auto_hide()
    call s:create_window_if_needed()
    call s:mappings_for_code_slices_window()
endfunction "}}}

fun! s:verify_not_called_from_slices() "{{{
    if &ft =~? 'slices$'
        throw 'CALLED FROM SLICES'
    endif
endfunction "}}}

fun! s:TabMoving (flag) "{{{
    call s:close_when_needed()
    if getline(line('.')) =~# '\v^Slice.*'
        normal zv
        let pos = getpos('.')
        call cursor(pos[1]+1, pos[2])
        normal zv
        return
    endif
    if a:flag == 'b'
        let pos = getpos('.')
        call cursor(pos[1] - 1, 0)
    endif
    let pos = searchpos('\v^Slice.*$', a:flag)
    if pos[0] == 0
        call cursor([1, 1])
        let pos = searchpos('\v^Slice.*$', a:flag)
        if pos[0] == 0
            throw 'No Slices'
        endif
        normal za
    endif
    call setpos('.', pos)
    call s:TabMoving(a:flag)
endfunction "}}}

fun! s:close_when_needed() "{{{
    if g:keep_open_unactive_slices == 0
        normal! zc
    endif
endfunction "}}}

fun! s:insert_current_slice_and_return(close_slices_window) "{{{
    call <SID>insert_current_slice(a:close_slices_window)
    call <SID>go_to_slices_window()
    return "\<Nop>"
endfunction "}}}

fun! s:mappings_for_code_slices_window() "{{{
    nnoremap <silent><buffer> q ZZ
    nnoremap <silent><buffer> u <Nop>
    nnoremap <silent><buffer> p <Nop>
    nnoremap <silent><buffer> P <Nop>
    nnoremap <silent><buffer> <C-o> <Nop>
    nnoremap <silent><buffer> <Tab> :call <SID>TabMoving('')<CR>
    nnoremap <silent><buffer> <BS> :call <SID>TabMoving('b')<CR>
    "Insert slice with <CR>
    nnoremap <silent><buffer> <CR> :call <SID>insert_current_slice(1)<CR>
    nnoremap <silent><buffer> o za
    "Insert slice and return to slices window
    nnoremap <silent><buffer> <leader><CR> :call <SID>insert_current_slice(0) \|
                \ call <SID>go_to_slices_window()<CR>
    nnoremap <silent><buffer> <space> :call <SID>insert_current_slice_and_return(0) <CR>
    augroup slices
        au!
        au InsertEnter <buffer> normal 
    augroup END
endfunction "}}}

fun! s:load_slices(ft)
    setl modifiable
    %d
    let files = findfile('slices/' . a:ft . '.slices', &rtp, -1)
    for filename in files
        call append(line('$'), readfile(filename))
    endfor
    1d
    1
    setl nomodifiable
endfunction

fun! s:create_window_if_needed() "{{{
    let working_window = bufnr('%')
    let type = &ft
    let current_window = bufwinnr('^slices$')
    if current_window < 0
        keepalt vertical belowrigh new
        setlocal wrap buftype=nowrite bufhidden=wipe nobuflisted noswapfile number
        f slices
    else
        call s:go_to_slices_window()
    endif
    vertical resize 45
    let b:last_window = working_window
    call s:load_slices(type)
    exe "set ft=" . type . ".slices"
endfunction "}}}

fun! s:go_to_slices_window() "{{{
    let current_window = bufwinnr('^slices$')
    silent! execute current_window.'wincmd w'
endfunction "}}}

fun! s:insert_current_slice(...) "{{{
    let auto_hide = 0
    if a:0 > 0
        let auto_hide = a:1
    endif
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
    call Update_and_format_buffer(lines)
    let slices_window = bufwinnr('^slices$')
    if auto_hide != 0 && slices_window != -1
        execute slices_window. 'wincmd w'
        close
    endif
endfunction "}}}

fun! Update_and_format_buffer(lines) "{{{
    let working_lines = a:lines
    "Preserve indentation
    "0 or more spaces not followed by a space and match all chars in line
    "and substitute with 0 or more matched spaces. Also match empty lines
    let line_spaces = substitute(getline(line('.')), '\v(^[[:space:]]*)([[:space:]])@!.*', '\1', '')
    for line_index in range(len(working_lines))
        let working_lines[line_index] = substitute(working_lines[line_index], '^', line_spaces, '')
    endfor

    if getline(line('.')) =~? '\v^[[:space:]]*$'
        call setline(line('.'), working_lines[0])
        let working_lines = working_lines[1:]
    endif

    call Append_Lines(working_lines)
    let line_nr = line('.') + len(working_lines)
    call setpos('.', [0, line_nr, len(getline(line_nr)), 0])
endfunction "}}}

fun! Append_lines(lines) "{{{
    let line_nr = line('.')
    for line in a:lines
        call append(line_nr, line)
        let line_nr += 1
    endfor
endfunction "}}}

fun! s:get_lines_from_bounds(bounds) "{{{
    let lines = []
    let first_line = getline(a:bounds['slice_start'])
    let pattern = '\v^[[:space:]]{' . &ts . '}'
    let correct_lines = 0

    if first_line =~? '\v^[[:space:]]'
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
        if getline('.') =~ '\v^Group'
            let pos = getpos('.')
            call cursor(pos[1] + 1, pos[2])
            normal zv
        endif
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

fun! s:prepare_to_auto_hide() "{{{
    let b:preserve_buffer = 1
    augroup prepare_auto_hide
        au!
        au BufEnter * call <SID>close_slices_if_needed()
    augroup END
endfunction "}}}

fun! s:close_slices_if_needed() "{{{
    if &ft =~? '\v.*slices$' || expand('%') == 'slices'
        let g:ignore_next_buf_enter = 1
        return
    endif

    if g:ignore_next_buf_enter == 1
        let g:ignore_next_buf_enter = 0
    else
        let slices_window =  bufwinnr('^slices$')
        if slices_window == -1
            return
        endif
        exe slices_window . ' wincmd w'
        close
        wincmd p
        augroup prepare_auto_hide
            au!
        augroup END
    endif
endfunction "}}}

fun! Set_Bot_FT() "{{{
    if &ft =~ '\v\.'
        return
    endif
    let additional_ft = expand('%:t:r')
    let ft_slices = &ft
    exe "set ft=" . additional_ft . '.' . ft_slices
endfunction "}}}

fun! CreateSliceFromLines(lines) "{{{
    
endfunction "}}}

fun! Extract_Lines(line_1, line_2) "{{{
    let lines = []
    for line_nr in range(a:line_1, a:line_2)
        echom line_nr
        let lines += [getline(line_nr)]
    endfor
    return lines
endfunction "}}}

au FileType slices call Set_Bot_FT()
au FileType slices normal zR
command! ShowSlices call s:show_slices()

