"=============================================================================
" FILE: interactive_command_complete.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 06 Jun 2010
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

function! vimshell#complete#interactive_command_complete#complete()"{{{
  if exists('&iminsert')
    let &l:iminsert = 0
  endif

  " Interactive completion.

  if exists(':NeoComplCacheDisable') && exists('*neocomplcache#complfunc#completefunc_complete#call_completefunc')
    return neocomplcache#complfunc#completefunc_complete#call_completefunc('vimshell#complete#interactive_command_complete#omnifunc')
  else
    " Set complete function.
    let &l:omnifunc = 'vimshell#complete#interactive_command_complete#omnifunc'

    return "\<C-x>\<C-o>\<C-p>"
  endif
endfunction"}}}

function! vimshell#complete#interactive_command_complete#omnifunc(findstart, base)"{{{
  if a:findstart
    let l:cur_text = vimshell#interactive#get_cur_text()
    let l:match = (l:cur_text !~ '\s')? 0 : match(l:cur_text, vimshell#get_argument_pattern())

    if l:match < 0
      return -1
    endif

    return len(vimshell#interactive#get_prompt(line('.'))) + l:match
  endif

  " Save option.
  let l:ignorecase_save = &ignorecase

  " Complete.
  if g:vimshell_smart_case && a:base =~ '\u'
    let &ignorecase = 0
  else
    let &ignorecase = g:vimshell_ignore_case
  endif

  let l:complete_words = s:get_complete_candidates(a:base)

  " Restore option.
  let &ignorecase = l:ignorecase_save
  if &l:omnifunc != ''
    let &l:omnifunc = ''
  endif

  return l:complete_words
endfunction"}}}

function! s:get_complete_candidates(cur_keyword_str)"{{{
  let l:list = []

  " Do command completion.
  let l:in = vimshell#interactive#get_cur_text()
  let l:prompt = getline('.')

  if b:interactive.encoding != '' && &encoding != &termencoding
    " Convert encoding.
    let l:in = iconv(l:in, &encoding, b:interactive.encoding)
  endif

  call b:interactive.process.write(l:in . s:get_complete_key())

  " Get output.
  let l:output = ''
  let l:cnt = 0
  while l:cnt <= 100
    let l:output .= b:interactive.process.read(-1, 40)

    let l:cnt += 1
  endwhile

  if b:interactive.encoding != '' && &encoding != &termencoding
    " Convert encoding.
    let l:output = iconv(l:output, b:interactive.encoding, &encoding)
  endif

  " Filtering escape sequences.
  let l:output = vimshell#terminal#filter(l:output)

  let l:candidates = split(join(split(l:output, '\r\n\|\n')[: -2], '  '), '\s')
  let l:cnt = 0
  let l:ignore_input = l:in[: -len(a:cur_keyword_str)-1]

  " Delete input.
  call b:interactive.process.write(repeat("\<C-h>", len(l:in)))

  let l:ret = []
  for l:candidate in l:candidates
    if vimshell#head_match(l:candidate, a:cur_keyword_str)
      " Delete last "/".
      let l:dict = {
            \'word' : l:candidate =~ '/$' ? l:candidate[: -2] : l:candidate, 
            \'abbr' : l:candidate
            \}
      call add(l:ret, l:dict)
    endif
  endfor

  return l:ret
endfunction"}}}

function! s:get_complete_key()"{{{
  if b:interactive.is_pty
    " For pty program.
    return "\<TAB>"
  elseif &filetype == 'int-zsh' || &filetype == 'int-nyaos' 
    return "\<C-d>"
  else
    " For readline program.
    return "\<ESC>?"
  endif
endfunction"}}}
" vim: foldmethod=marker
