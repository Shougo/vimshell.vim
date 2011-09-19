"=============================================================================
" FILE: helper.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 19 Sep 2011.
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

function! vimshell#complete#helper#files(cur_keyword_str, ...)"{{{
  " vimshell#complete#helper#files(cur_keyword_str [, path])

  if a:0 > 1
    echoerr 'Too many arguments.'
  endif

  if !exists('*neocomplcache#sources#filename_complete#get_complete_words')
    return []
  endif

  let path = (a:0 == 1 ? a:1 : '.')
  let list = neocomplcache#sources#filename_complete#get_complete_words(a:cur_keyword_str, path)

  " Extend pseudo files.
  if a:cur_keyword_str =~ '^/dev/'
    for word in vimshell#complete#helper#keyword_simple_filter(
          \  ['/dev/null', '/dev/clip', '/dev/quickfix'],
          \ a:cur_keyword_str)
      let dict = {
            \ 'word' : word, 'menu' : 'file'
            \}

      " Escape word.
      let dict.orig = dict.word
      let dict.word = escape(dict.word, ' *?[]"={}')

      call add(list, dict)
    endfor
  endif

  return list
endfunction"}}}
function! vimshell#complete#helper#directories(cur_keyword_str)"{{{
  let ret = []
  for keyword in filter(vimshell#complete#helper#files(a:cur_keyword_str),
        \ 'isdirectory(expand(v:val.orig)) || (vimshell#iswin() && fnamemodify(v:val.orig, ":e") ==? "LNK" && isdirectory(resolve(expand(v:val.orig))))')
    let dict = keyword
    let dict.menu = 'directory'

    call add(ret, dict)
  endfor

  return ret
endfunction"}}}
function! vimshell#complete#helper#cdpath_directories(cur_keyword_str)"{{{
  " Check dup.
  let check = {}
  for keyword in filter(vimshell#complete#helper#files(a:cur_keyword_str, &cdpath), 
        \ 'isdirectory(expand(v:val.orig)) || (vimshell#iswin() && fnamemodify(expand(v:val.orig), ":e") ==? "LNK" && isdirectory(resolve(expand(v:val.orig))))')
    if !has_key(check, keyword.word) && keyword.word =~ '/'
      let check[keyword.word] = keyword
    endif
  endfor

  let ret = []
  for keyword in values(check)
    let dict = keyword
    let dict.menu = 'cdpath'

    call add(ret, dict)
  endfor

  return ret
endfunction"}}}
function! vimshell#complete#helper#directory_stack(cur_keyword_str)"{{{
  if !exists('b:vimshell')
    return []
  endif

  let ret = []

  for keyword in vimshell#complete#helper#keyword_simple_filter(range(len(b:vimshell.directory_stack)), a:cur_keyword_str)
    let dict = { 'word' : keyword, 'menu' : b:vimshell.directory_stack[keyword] }

    call add(ret, dict)
  endfor

  return ret
endfunction"}}}
function! vimshell#complete#helper#aliases(cur_keyword_str)"{{{
  if !exists('b:vimshell')
    return []
  endif

  let ret = []
  for keyword in vimshell#complete#helper#keyword_simple_filter(keys(b:vimshell.alias_table), a:cur_keyword_str)
    let dict = { 'word' : keyword }

    if len(b:vimshell.alias_table[keyword]) > 15
      let dict.menu = 'alias ' . printf("%s..%s", b:vimshell.alias_table[keyword][:8], b:vimshell.alias_table[keyword][-4:])
    else
      let dict.menu = 'alias ' . b:vimshell.alias_table[keyword]
    endif

    call add(ret, dict)
  endfor

  return ret
endfunction"}}}
function! vimshell#complete#helper#internals(cur_keyword_str)"{{{
  let commands = vimshell#available_commands()
  let ret = []
  for keyword in vimshell#complete#helper#keyword_simple_filter(keys(commands), a:cur_keyword_str)
    let dict = { 'word' : keyword, 'menu' : commands[keyword].kind }
    call add(ret, dict)
  endfor 

  return ret
endfunction"}}}
function! vimshell#complete#helper#executables(cur_keyword_str, ...)"{{{
  if a:cur_keyword_str =~ '[/\\]'
    let files = vimshell#complete#helper#files(a:cur_keyword_str)
  else
    let path = a:0 > 1 ? a:1 : vimshell#iswin() ? substitute($PATH, '\\\?;', ',', 'g') : substitute($PATH, '/\?:', ',', 'g')
    let files = vimshell#complete#helper#files(a:cur_keyword_str, path)
  endif

  if vimshell#iswin()
    let exts = escape(substitute($PATHEXT, ';', '\\|', 'g'), '.')
    let pattern = (a:cur_keyword_str =~ '[/\\]')?
          \ 'isdirectory(expand(v:val.orig)) || "." . fnamemodify(v:val.orig, ":e") =~? '.string(exts) :
          \ '"." . fnamemodify(v:val.orig, ":e") =~? '.string(exts)
  else
    let pattern = (a:cur_keyword_str =~ '[/\\]')?
          \ 'isdirectory(expand(v:val.orig)) || executable(expand(v:val.orig))' : 'executable(expand(v:val.orig))'
  endif

  call filter(files, pattern)

  let ret = []
  for keyword in files
    let dict = keyword
    let dict.menu = 'command'
    if a:cur_keyword_str !~ '[/\\]'
      let dict.word = fnamemodify(keyword.word, ':t')
      let dict.abbr = fnamemodify(keyword.abbr, ':t')
    endif

    call add(ret, dict)
  endfor

  return ret
endfunction"}}}
function! vimshell#complete#helper#buffers(cur_keyword_str)"{{{
  let ret = []
  let bufnumber = 1
  while bufnumber <= bufnr('$')
    if buflisted(bufnumber) && vimshell#head_match(bufname(bufnumber), a:cur_keyword_str)
      let keyword = bufname(bufnumber)
      let dict = { 'word' : escape(keyword, ' *?[]"={}'), 'menu' : 'buffer' }
      call add(ret, dict)
    endif

    let bufnumber += 1
  endwhile

  return ret
endfunction"}}}
function! vimshell#complete#helper#args(command, args)"{{{
  let commands = vimshell#available_commands()

  " Get complete words.
  let complete_words = has_key(commands, a:command) && has_key(commands[a:command], 'complete') ?
        \ commands[a:command].complete(a:args) : vimshell#complete#helper#files(a:args[-1])

  if a:args[-1] =~ '^--\?[[:alnum:]._-]\+=\f\+$\|[<>]\+\f\+$'
    " Complete file.
    let prefix = matchstr(a:args[-1],
          \'^--[[:alnum:]._-]\+=\|^[<>]\+')
    let complete_words += vimshell#complete#helper#files(a:args[-1][len(prefix): ])
  endif

  return complete_words
endfunction"}}}
function! vimshell#complete#helper#command_args(args)"{{{
  " command args...
  if len(a:args) == 1
    " Commands.
    return vimshell#complete#helper#executables(a:args[0])
  else
    " Args.
    return vimshell#complete#helper#args(a:args[0], a:args[1:])
  endif
endfunction"}}}

function! vimshell#complete#helper#call_omnifunc(omnifunc)"{{{
  " Note: neocomplcache#sources#completefunc_complete#call_completefunc()
  "     is not working. :-(
  " if exists(':NeoComplCacheDisable')
  if 0
    return neocomplcache#sources#completefunc_complete#call_completefunc(a:omnifunc)
  else
    " Set complete function.
    let &l:omnifunc = a:omnifunc

    return "\<C-x>\<C-o>\<C-p>"
  endif
endfunction"}}}
function! vimshell#complete#helper#restore_omnifunc(omnifunc)"{{{
  if &l:omnifunc !=# a:omnifunc
    let &l:omnifunc = a:omnifunc
  endif
endfunction"}}}
function! vimshell#complete#helper#compare_rank(i1, i2)"{{{
  return a:i1.rank < a:i2.rank ? 1 : a:i1.rank == a:i2.rank ? 0 : -1
endfunction"}}}
function! vimshell#complete#helper#keyword_filter(list, cur_keyword_str)"{{{
  let cur_keyword = substitute(a:cur_keyword_str, '\\\zs.', '\0', 'g')
  if &ignorecase
    let expr = printf('stridx(tolower(v:val.word), %s) == 0', string(tolower(cur_keyword)))
  else
    let expr = printf('stridx(v:val.word, %s) == 0', string(cur_keyword))
  endif

  return filter(a:list, expr)
endfunction"}}}
function! vimshell#complete#helper#keyword_simple_filter(list, cur_keyword_str)"{{{
  let cur_keyword = substitute(a:cur_keyword_str, '\\\zs.', '\0', 'g')
  if &ignorecase
    let expr = printf('stridx(tolower(v:val), %s) == 0', string(tolower(cur_keyword)))
  else
    let expr = printf('stridx(v:val, %s) == 0', string(cur_keyword))
  endif

  return filter(a:list, expr)
endfunction"}}}

" vim: foldmethod=marker
