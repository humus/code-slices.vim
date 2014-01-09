"if exists( "g:loaded_code_slices" )
    "finish
"endif
let g:loaded_code_slices = 1

" variable used in a little hack to auto-close slices window, since slices
" window is directly related to buffer which exec the ShowSlices commnand at
" least for now the less error-prone alternative is to close that window
let g:ignore_next_buf_enter = 0
let g:slices_tab_space = 2

if !exists("g:slices_use_vertical_split")
    let g:slices_use_vertical_split = 1
endif

if !exists( "g:slices_preferred_path" )
    let g:slices_preferred_path = fnameescape(expand('$HOME') . '/.vim')
    if has('win32')
        let g:slices_preferred_path = fnameescape(expand('$HOME') . '\vimfiles')
    endif
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
    let b:auto_close_folds=1
endfunction "}}}

fun! s:load_slices(ft)
    setl modifiable
    %d
    let old_rtp = &rtp
    let &rtp = g:slices_preferred_path . ',' . &rtp
    let files = findfile('slices/' . a:ft . '.slices', &rtp, -1)
    for filename in files
        call append(line('$'), readfile(filename))
    endfor
    let &rtp = old_rtp
    1d
    1
    setl nomodifiable
endfunction

fun! s:create_window_if_needed() "{{{
  let working_window = bufnr('%')
  let type = &ft
  let current_window = bufwinnr('^slices$')
  if current_window < 0
    call s:open_slices_window()
  else
    call s:go_to_slices_window()
  endif
  let b:last_window = working_window
  call s:load_slices(type)
  exe "set ft=" . type . ".slices"
  normal zM
  call SlicesTabMoving('')
  normal zv
  1
  let g:ignore_next_buf_enter = 1
endfunction "}}}

fun! s:open_slices_window()
  if g:slices_use_vertical_split
    keepalt vertical botrigh new
    vertical resize 45
  else
    keepalt botright new
    resize 10
  endif
  f slices
  setlocal wrap buftype=nowrite bufhidden=wipe nobuflisted noswapfile number
  setf slices
endfunction

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

  if s:perform_fluent_slice_insert(bounds)
    return
  endif

  let lines = s:get_lines_from_bounds(bounds)
  if s:switch_to_destination_buffer() == -1
    echohl WarningMsg | echo 'Window not reacheable' | echohl None
    return
  endif
  call Update_and_format_buffer(lines)
  let slices_window = bufwinnr('^slices$')
  if auto_hide != 0 && slices_window != -1
    execute slices_window. 'wincmd w'
    close
  endif
endfunction "}}}

fun! s:switch_to_destination_buffer() "{{{
  let destination = bufwinnr(b:last_window)
  if destination != -1
    execute destination . 'wincmd w'
  endif
  return destination
endfunction "}}}

fun! s:perform_fluent_slice_insert(bounds) "{{{
  let first_line = getline(a:bounds['slice_start'])
  let retval = 0
  if first_line =~# '\vFluentSlice.*'
    let bounds = a:bounds
    let bounds['slice_start'] += 1

    let slice_lines = s:get_lines_from_bounds(bounds)
    let fluent_line_idx = line('.') - bounds['slice_start']
    if s:switch_to_destination_buffer()
      if !exists('s:reference_line')
        let s:reference_line = line('.')
      endif
      let slice_lines = s:format_lines_in_slice(slice_lines, s:reference_line)
      let fluent_line = slice_lines[fluent_line_idx]
      if getline(line('.')) =~? '\v^[[:space:]]*$'
        call setline(line('.'), fluent_line)
      else
        call Append_lines([fluent_line])
      endif
      call setpos('.', [0, line('.') + 1, len(getline(line('.')+1)), 0])
      let slices_window = bufwinnr('^slices$')
      execute slices_window . 'wincmd w'
      call setpos('.', [0, line('.') + 1, virtcol('.'), 0])
      if line('.') > a:bounds['slice_end'] || line('.') == line('$')
        unlet s:reference_line
        close
      endif
    endif
    let retval = 1
  endif

  return retval
endfunction "}}}

fun! s:format_lines_in_slice(lines, linenr) "{{{
  let working_lines = Normalize_indent(a:lines)
  "Preserve indentation
  "0 or more spaces not followed by a space and match all chars in line
  "and substitute with 0 or more matched spaces. Also match empty lines
  let line_spaces = substitute(getline(a:linenr), '\v(^[[:space:]]*)([[:space:]])@!.*', '\1', '')
  for line_index in range(len(working_lines))
    let working_lines[line_index] = substitute(working_lines[line_index], '^', line_spaces, '')
  endfor
  return working_lines
endfunction "}}}

fun! Update_and_format_buffer(lines) "{{{
  let working_lines = s:format_lines_in_slice(a:lines, line('.'))
  if getline(line('.')) =~? '\v^[[:space:]]*$'
    call setline(line('.'), working_lines[0])
    let working_lines = working_lines[1:]
  endif

  call Append_lines(working_lines)
  let line_nr = line('.') + len(working_lines)
  call setpos('.', [0, line_nr, len(getline(line_nr)), 0])
endfunction "}}}

fun! Normalize_indent(lines) "{{{
  let working_lines = a:lines

  if g:slices_tab_space != &ts
    for index in range(len(working_lines))
      let len_indent = len(substitute(working_lines[index], '\v^(\s*)(\s)@!.*', '\1', ''))
      let indent_level = len_indent / g:slices_tab_space
      let buffer_indent = ''
      let counter = 0
      for position in range(indent_level * &ts)
        let buffer_indent .= ' '
      endfor
      let working_lines[index] = substitute(working_lines[index], '\v^(\s+)(\s)@!', buffer_indent, '')
    endfor
  endif

  return working_lines
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
    let pattern = '\v^[[:space:]]{' . g:slices_tab_space . '}'
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
  if getline('.') =~ '\v^((Fluent)?Slice|Group)'
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
    if getline(line_nr) =~# '\vFluentSlice'
      return line_nr
    endif
    if getline(line_nr) =~# '\vSlice'
      return line_nr + 1
    endif
    if getline(line_nr) =~# '\v^Group'
      throw 'BAD_FORMAT: No slice after group'
    endif
  endfor
endfunction "}}}

fun! s:find_slice_end() "{{{
    let count_empty_lines = 0
    for line_nr in range(line('.') + 1, line('$'))
        if getline(line_nr) =~# '\v^(Group|Slice)'
            return line_nr - 1
        endif
        if getline(line_nr) =~# '\v^$'
            let count_empty_lines += 1
            if count_empty_lines > 1
                return line_nr
            endif
        endif
    endfor
    return line('$')
endfunction "}}}

fun! s:prepare_to_auto_hide() "{{{
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

fun! Extract_Lines(line_1, line_2) "{{{
    let lines = []
    for line_nr in range(a:line_1, a:line_2)
        let lines += [getline(line_nr)]
    endfor
    return lines
endfunction "}}}

fun! s:get_lines_from_file(file_name) "{{{
    let lines = []
    if filereadable(a:file_name)
        let lines = readfile(a:file_name)
    endif
    return lines
endfunction "}}}

fun! New_slice_from_range(...) range "{{{
    let slices_file = g:slices_preferred_path . '/slices/' . &ft . '.slices'
    let lines_in_file = s:get_lines_from_file(slices_file)
    let lines_in_slice = []
    if !Has_pending_group_last(lines_in_file)
        let lines_in_slice += ['Group pending']
    endif

    let slice_name = s:first_arg_or_input(a:0, a:000, "Slice's name: ")
    let slice_name=substitute('Slice ' . slice_name, '\v^\s*|\s*$', '' , 'g')

    let lines_in_slice += [slice_name]
                \ + s:format_slice_lines(Extract_Lines(a:firstline, a:lastline))

    let lines_in_file += lines_in_slice

    call writefile(lines_in_file, slices_file)
    call Update_slices_window(lines_in_file)
endfunction "}}}

fun! s:first_arg_or_input(total_args, arg_list, prompt_str) "{{{
    let retval = ''
    if a:total_args == 0 || a:arg_list[0] == ''
        let retval = input(a:prompt_str)
    else
        let retval = a:arg_list[0]
    endif
    return retval
endfunction "}}}

fun! s:format_slice_lines(lines_in_slice) "{{{
  let counter = 0
  let lines = a:lines_in_slice
  let sample = lines[0]
  let subexpression = '\s{' . &ts . '}'
  if !&et
    let subexpression = '\t'
  endif

  let substitution_expression = '\v^' . subexpression
  let search_expression = substitution_expression . subexpression

  while sample =~# search_expression
    let sample = substitute(sample, substitution_expression, '', '')
    let counter+=1
  endwhile

  let fix_expr = '\v^\s{' . &ts * counter . '}'

  if !&et
    let fix_expr = '\v^\t{' . counter . '}'
  endif

  let ret_lines = []

  for line in lines
    call add(ret_lines, s:format_to_slices_indent(substitute(line, fix_expr, '', '')))
  endfor

  return ret_lines
endfunction "}}}

fun! s:format_to_slices_indent(line) "{{{
  let ret_line = a:line
  if &ts != g:slices_tab_space
    let indent_level = len(split(ret_line, '\v\s{' . &ts . '}', 1)) - 1
    let indent = ''
    for level in range(g:slices_tab_space * indent_level)
      let indent .= ' '
    endfor
    let ret_line = substitute(ret_line, '\v\s*', indent, '')
  endif
  return ret_line
endfunction "}}}

fun! Update_slices_window(lines_in_file) "{{{
  "close slices window
  let slices_window = bufwinnr('^slices$')
  if slices_window == -1
    return
  endif
  exe slices_window . 'wincmd w'
  setl modifiable
  %d
  call setline(1, a:lines_in_file[0])
  call append(1, a:lines_in_file[1:])
  normal zM
  normal G
  normal zv
  call SlicesTabMoving('b')
  setl nomodifiable
  "go back to previous window
  wincmd p
endfunction "}}}

fun! Has_pending_group_last(lines) "{{{
  let l_lines = reverse(deepcopy(a:lines))
  for line in l_lines
    if line =~# '^Group'
      return line =~? 'pending'
    endif
  endfor
  return 0
endfunction "}}}

fun! s:edit_slices_file() "{{{
  let path = g:slices_preferred_path . '/slices/' . &ft . '.slices'
  exe "e " . path
endfunction "}}}

au FileType slices call Set_Bot_FT()
command! ShowSlices call s:show_slices()
command! -nargs=? -range=1 CreateSlice <line1>,<line2> call New_slice_from_range(<q-args>)
command! -nargs=? EditSlicesFile call <SID>edit_slices_file()

