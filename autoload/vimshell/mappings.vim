"=============================================================================
" FILE: mappings.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 08 Apr 2010
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

" VimShell key-mappings functions.
function! vimshell#mappings#push_current_line()"{{{
    " Check current line.
    if match(getline('.'), vimshell#escape_match(vimshell#get_prompt())) < 0
        return
    endif

    call add(b:vimshell.commandline_stack, getline('.'))

    " Set prompt line.
    call setline(line('.'), vimshell#get_prompt())

    startinsert!
endfunction"}}}
function! vimshell#mappings#push_and_execute(command)"{{{
    " Check current line.
    if match(getline('.'), vimshell#escape_match(vimshell#get_prompt())) < 0
        return
    endif

    call add(b:vimshell.commandline_stack, getline('.'))

    " Set prompt line.
    call setline(line('.'), vimshell#get_prompt() . a:command)

    call vimshell#mappings#execute_line(1)
endfunction"}}}

function! vimshell#mappings#execute_line(is_insert)"{{{
  if !vimshell#check_prompt()
    " Prompt not found

    if !vimshell#check_prompt('$')
      " Create prompt line.
      call append('$', vimshell#get_prompt())
    endif

    if getline('.') =~ '^\s*\d\+:\s[^[:space:]]'
      " History output execution.
      call setline('$', vimshell#get_prompt() . matchstr(getline('.'), '^\s*\d\+:\s\zs.*'))
    else
      " Search cursor file.
      let l:filename = substitute(substitute(expand('<cfile>'), ' ', '\\ ', 'g'), '\\', '/', 'g')
      if l:filename == ''
        return
      endif

      " Execute cursor file.
      if l:filename =~ '^\%(https\?\|ftp\)://'
        " Open uri.
        call setline('$', vimshell#get_prompt() . 'open ' . l:filename)
      elseif isdirectory(expand(l:filename))
        " Change directory.
        call setline('$', vimshell#get_prompt() . 'cd ' . l:filename)
      else
        " Edit file.
        call setline('$', vimshell#get_prompt() . 'vim ' . l:filename)
      endif
    endif
  elseif line('.') != line('$')
    " History execution.
    if !vimshell#check_prompt('$')
      " Insert prompt line.
      call append('$', getline('.'))
    else
      " Set prompt line.
      call setline('$', getline('.'))
    endif
  endif

  $

  " Get command line.
  let l:line = vimshell#get_prompt_command()
  let l:context = {
        \ 'has_head_spaces' : l:line =~ '^\s\+',
        \ 'is_interactive' : 1, 
        \ 'is_insert' : a:is_insert, 
        \ 'fd' : { 'stdin' : '', 'stdout': '', 'stderr': ''}, 
        \}

  if l:line =~ '^\s*$'
    " Call emptycmd hook.
    for l:func_name in values(b:vimshell.hook_functions_table['emptycmd'])
      call call(l:func_name, [l:context])
    endfor
  else
    " Call preexec hook.
    for l:func_name in values(b:vimshell.hook_functions_table['preexec'])
      call call(l:func_name, [l:context])
    endfor
  endif

  " Get command line again.
  " Because: hook functions may change command line.
  let l:line = vimshell#get_prompt_command()

  if exists('vimshell#hist_size') && getfsize(g:VimShell_HistoryPath) != vimshell#hist_size
    " Reload.
    let g:vimshell#hist_buffer = readfile(g:VimShell_HistoryPath)
  endif
  " Not append history if starts spaces or dups.
  if l:line !~ '^\s'
    call vimshell#append_history(l:line)
  endif

  " Delete head spaces.
  let l:line = substitute(l:line, '^\s\+', '', '')
  if l:line =~ '^\s*-\s*$'
    " Popd.
    call vimshell#execute_internal_command('cd', ['-'], {}, {})
  endif

  if l:line =~ '^\s*$\|^\s*-\s*$'
    call vimshell#print_prompt(l:context)

    if a:is_insert
      call vimshell#start_insert()
    else
      normal! $
    endif
    return
  endif

  try
    let l:skip_prompt = vimshell#parser#eval_script(l:line, l:context)
  catch /.*/
    let l:message = v:exception . ' ' . v:throwpoint
    call vimshell#error_line({}, l:message)
    
    call vimshell#print_prompt(l:context)

    if a:is_insert
      call vimshell#start_insert()
    else
      normal! $
    endif
    return
  endtry

  if l:skip_prompt
    " Skip prompt.
    return
  endif

  call vimshell#print_prompt(l:context)
  if a:is_insert
    call vimshell#start_insert()
  else
    normal! $
  endif
endfunction"}}}
function! vimshell#mappings#previous_prompt()"{{{
    call search('^' . vimshell#escape_match(vimshell#get_prompt()), 'bWe')
endfunction"}}}
function! vimshell#mappings#next_prompt()"{{{
    call search('^' . vimshell#escape_match(vimshell#get_prompt()), 'We')
endfunction"}}}
function! vimshell#mappings#delete_previous_output()"{{{
    let l:prompt = vimshell#escape_match(vimshell#get_prompt())
    if vimshell#get_user_prompt() != ''
        let l:nprompt = '^\[%\] '
    else
        let l:nprompt = '^' . l:prompt
    endif
    let l:pprompt = '^' . l:prompt
    
    " Search next prompt.
    if getline('.') =~ l:nprompt
        let l:next_line = line('.')
    elseif vimshell#get_user_prompt() != '' && getline('.') =~ '^' . l:prompt
        let [l:next_line, l:next_col] = searchpos(l:nprompt, 'bWn')
    else
        let [l:next_line, l:next_col] = searchpos(l:nprompt, 'Wn')
    endif
    while getline(l:next_line-1) =~ l:nprompt
        let l:next_line -= 1
    endwhile

    normal! 0
    let [l:prev_line, l:prev_col] = searchpos(l:pprompt, 'bWn')
    if l:prev_line > 0 && l:next_line - l:prev_line > 1
        execute printf('%s,%sdelete', l:prev_line+1, l:next_line-1)
        call append(line('.')-1, "* Output was deleted *")
    endif
    call vimshell#mappings#next_prompt()
endfunction"}}}
function! vimshell#mappings#insert_last_word()"{{{
    let l:word = ''
    if !empty(g:vimshell#hist_buffer)
        for w in reverse(split(g:vimshell#hist_buffer[0], '[^\\]\zs\s'))
            if w =~ '[[:alpha:]_/\\]\{2,}'
                let l:word = w
                break
            endif
        endfor
    endif
    call setline(line('.'), getline('.') . l:word)
    startinsert!
endfunction"}}}
function! vimshell#mappings#run_help()"{{{
    if match(getline('.'), vimshell#escape_match(vimshell#get_prompt())) < 0
        startinsert!
        return
    endif

    " Delete prompt string.
    let l:line = substitute(getline('.'), '^' . vimshell#escape_match(vimshell#get_prompt()), '', '')
    if l:line =~ '^\s*$'
        startinsert!
        return
    endif

    let l:program = split(l:line)[0]
    if l:program !~ '\h\w*'
        startinsert!
        return
    elseif has_key(b:vimshell.alias_table, l:program)
        let l:program = b:vimshell.alias_table[l:program]
    elseif has_key(b:vimshell.galias_table, l:program)
        let l:program = b:vimshell.galias_table[l:program]
    endif

    if exists(':Man')
        execute 'Man' l:program
    elseif exists(':Ref')
        execute 'Ref man' l:program
    else
        call vimshell#execute_internal_command('bg', ['man', '-P', 'cat', l:program], 
                    \{}, {'is_interactive' : 0})
    endif
endfunction"}}}
function! vimshell#mappings#paste_prompt()"{{{
    if match(getline('.'), vimshell#escape_match(vimshell#get_prompt())) < 0
        return
    endif

    if match(getline('$'), vimshell#escape_match(vimshell#get_prompt())) < 0
        " Insert prompt line.
        call append(line('$'), getline('.'))
    else
        " Set prompt line.
        call setline(line('$'), getline('.'))
    endif
    $
endfunction"}}}
function! vimshell#mappings#move_head()"{{{
    call search(vimshell#escape_match(vimshell#get_prompt()), 'be', line('.'))
    if col('.') != col('$')-1
        normal! l
    endif
    startinsert
endfunction"}}}
function! vimshell#mappings#move_end_argument()"{{{
    normal! 0
    call search('\\\@<!\s\zs[^[:space:]]*$', '', line('.'))
endfunction"}}}
function! vimshell#mappings#delete_line()"{{{
    let l:col = col('.')
    let l:mcol = col('$')
    call setline(line('.'), vimshell#get_prompt() . getline('.')[l:col :])
    call vimshell#mappings#move_head()
    if l:col == l:mcol-1
        startinsert!
    endif
endfunction"}}}
function! vimshell#mappings#clear()"{{{
    " Clean up the screen.
    let l:line = getline('.')
    let l:pos = getpos('.')
    % delete _

    if vimshell#get_user_prompt() != ''
        " Insert user prompt line.
        for l:user in split(vimshell#get_user_prompt(), "\\n")
            let l:secondary = '[%] ' . eval(l:user)
            if line('$') == 1 && getline('.') == ''
                call setline(line('$'), l:secondary)
            else
                call append(line('$'), l:secondary)
                normal! j$
            endif
        endfor
    endif

    call append(line('.'), l:line)
    call setpos('.', l:pos)
    if col('.')+1 < col('$')
        normal! l
        startinsert
    else
        startinsert!
    endif
endfunction"}}}
function! vimshell#mappings#expand_wildcard()"{{{
    " Wildcard.
    let l:wildcard = matchstr(vimshell#get_cur_text(), '[^[:blank:]]*$')
    let l:expanded = vimshell#parser#expand_wildcard(l:wildcard)
    
    return (pumvisible() ? "\<C-e>" : '')
                \ . repeat("\<BS>", len(l:wildcard)) . join(l:expanded)
endfunction"}}}

" vim: foldmethod=marker
