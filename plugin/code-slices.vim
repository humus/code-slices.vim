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

fun! s:show_slices(...) abort "{{{
  let ftype = ''
  if a:0 > 0
    let ftype = a:1
  endif
  try
    call s:verify_not_called_from_slices()
  catch /CALLED FROM SLICES/
    echohl WarningMsg | echo 'Recursive slices not allowed' | echohl None
    return
  endtry
  call s:prepare_to_auto_hide()
  try
    call s:create_window_if_needed(ftype)
    call s:mappings_for_code_slices_window()
  catch /No Slices/
    echohl WarningMsg | echo 'No Slices' | echohl None
  endtry
endfunction "}}}

fun! s:verify_not_called_from_slices() "{{{
  if &ft =~? 'slices$'
    throw 'CALLED FROM SLICES'
  endif
endfunction "}}}

fun! s:insert_current_slice_and_return(close_slices_window, count) "{{{
  call <SID>insert_current_slice(a:close_slices_window, a:count)
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
  nnoremap <silent><buffer> <CR> :<C-U>call <SID>insert_current_slice(1, v:count1)<CR>
  nnoremap <silent><buffer> o za
  nnoremap <silent><buffer> <space> :<C-U>call <SID>insert_current_slice_and_return(0, v:count1)<CR>
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
  if line('$') == 1
    return 0
  endif
  let &rtp = old_rtp
  1d
  1
  setl nomodifiable
  return 1
endfunction

fun! s:create_window_if_needed(ftype) "{{{
  let type = a:ftype
  if type == ''
    let type=&ft
  endif
  let working_window = bufnr('%')
  let current_window = bufwinnr('^slices$')
  if current_window < 0
    call s:open_slices_window()
  else
    call s:go_to_slices_window()
  endif
  let slices_exists = s:load_slices(type)

  if !slices_exists
    close
    throw 'No Slices'
  endif

  let b:last_window = working_window
  exe "set ft=" . type . ".slices"
  normal zM
  call SlicesTabMoving('')
  normal zv
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
  silent f slices
  setlocal wrap buftype=nowrite bufhidden=wipe nobuflisted noswapfile number
endfunction

fun! s:go_to_slices_window() "{{{
  let current_window = bufwinnr('^slices$')
  silent! execute current_window.'wincmd w'
endfunction "}}}

fun! s:insert_current_slice(auto_hide, count) "{{{
  let auto_hide = a:auto_hide
  let bounds = s:find_slice_bounds()
  if !has_key(bounds, 'slice_start')
    echohl WarningMsg | echo 'Not a slice' | echohl None
    return
  endif

  if s:perform_fluent_slice_insert(bounds, a:count)
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

fun! s:perform_fluent_slice_insert(bounds, count) abort "{{{
  let first_line = getline(a:bounds['slice_start'])
  let retval = 0
  if first_line =~# '\vFluentSlice.*'
    let bounds = a:bounds
    let bounds['slice_start'] += 1
    let slices_window = bufwinnr('^slices$')

    let slice_lines = s:get_lines_from_bounds(bounds)
    let fluent_line_idx = line('.') - bounds['slice_start']
    let cur_line = line('.')
    if s:switch_to_destination_buffer()
      call s:ensure_reference_line()
      let slice_lines = s:format_lines_in_slice(slice_lines, s:reference_line)
      let insert_num = 1
      while fluent_line_idx < len(slice_lines) && insert_num <= a:count
        let fluent_line = slice_lines[fluent_line_idx]
        call s:append_fluent_line(fluent_line)
        call setpos('.', [0, line('.') + 1, len(getline(line('.')+1)), 0])
        execute slices_window . 'wincmd w'
        let cur_line = line('.')
        call setpos('.', [0, cur_line + 1, virtcol('.'), 0])
        let insert_num += 1
        let fluent_line_idx +=1
        call s:switch_to_destination_buffer()
      endwhile
      execute slices_window . 'wincmd w'
      if cur_line + 1 > bounds['slice_end'] || cur_line + 1 > line('$')
        unlet s:reference_line
        close
      endif
    endif
    let retval = 1
  endif

  return retval
endfunction "}}}

fun! s:append_fluent_line(fluent_line) "{{{
  if getline(line('.')) =~? '\v^[[:space:]]*$'
    call setline(line('.'), a:fluent_line)
  else
    call Append_lines([a:fluent_line])
  endif
endfunction "}}}

fun! s:ensure_reference_line() "{{{
  if !exists('s:reference_line')
    let s:reference_line = line('.')
  endif
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
  if getline('.') =~# '\v^((Fluent)?Slice|Group)'
    if getline('.') =~# '\v^Group'
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
    if getline(line_nr) =~# '\v^(Group|Slice|FluentSlice)'
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

fun! New_fluent_slice_from_range(...) range "{{{
  let slice_name = s:first_arg_or_input(a:0, a:000, "Slice's name: ")
  call s:new_slice(slice_name, 'Fluent', a:firstline, a:lastline)
endfunction "}}}

fun! New_slice_from_range(...) range "{{{
  let slice_name = s:first_arg_or_input(a:0, a:000, "Slice's name: ")
  call s:new_slice(slice_name, '', a:firstline, a:lastline)
endfunction "}}}

fun! s:new_slice(name, prefix, line1, line2) "{{{
  let slices_dir = g:slices_preferred_path . '/slices/' 
  if !isdirectory(slices_dir)
      call mkdir(slices_dir, 'p')
  endif
  let slices_file = slices_dir . &ft . '.slices'
  let lines_in_file = s:get_lines_from_file(slices_file)
  let lines_in_slice = []
  if !Has_pending_group_last(lines_in_file)
    let lines_in_slice += ['Group pending']
  endif

  let slice_name=substitute(a:prefix . 'Slice ' . a:name, '\v^\s*|\s*$', '' , 'g')
  let lines_in_slice += [slice_name]
        \ + s:format_slice_lines(Extract_Lines(a:line1, a:line2))

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

fun! s:show_slices_group(group) "{{{
  call s:show_slices()
  normal zM
  let pos = searchpos('^Group ' . a:group)
  if pos[0] == 0
    normal zv
  else
    call setpos('.', [0, pos[0], pos[1], 0])
    call SlicesTabMoving('')
  endif
endfunction "}}}

au FileType slices call Set_Bot_FT()
command! -nargs=? ShowSlices call s:show_slices(<f-args>)
command! -nargs=? EditSlicesFile call <SID>edit_slices_file()
command! -nargs=? -range=1       CreateSlice <line1>,<line2> call New_slice_from_range(<q-args>)
command! -nargs=? -range=1 CreateFluentSlice <line1>,<line2> call New_fluent_slice_from_range(<q-args>)
command! -nargs=1 ShowSlicesGroup call s:show_slices_group(<q-args>)

