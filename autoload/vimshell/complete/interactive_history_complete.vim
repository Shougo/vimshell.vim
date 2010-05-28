"=============================================================================
" FILE: interactive_complete.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 28 May 2010
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

function! vimshell#complete#interactive_complete#complete()"{{{
  if exists('&iminsert')
    let &l:iminsert = 0
  endif

  " Interactive completion.

  if exists(':NeoComplCacheDisable') && exists('*neocomplcache#complfunc#completefunc_complete#call_completefunc')
    return neocomplcache#complfunc#completefunc_complete#call_completefunc('vimshell#complete#interactive_complete#omnifunc')
  else
    " Set complete function.
    let &l:omnifunc = 'vimshell#complete#interactive_complete#omnifunc'

    return "\<C-x>\<C-o>\<C-p>"
  endif
endfunction"}}}

function! vimshell#complete#interactive_complete#omnifunc(findstart, base)"{{{
  if a:findstart
    return match(vimshell#get_interactive_cur_text(), '\%([[:alnum:]_+~-]\|\\[ ]\)*$')
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
  let l:in = getline('.')
  let l:prompt = l:in

  if l:in == '...'
    let l:in = ''
    " Working
  elseif !exists('b:prompt_history')
    let b:prompt_history = {}
    let l:in = ''
  elseif exists("b:prompt_history['".line('.')."']")
    let l:in = l:in[len(b:prompt_history[line('.')]) : ]
  endif

  if &termencoding != '' && &encoding != &termencoding
    " Convert encoding.
    let l:in = iconv(l:in, &encoding, &termencoding)
  endif

  call b:vimproc_sub[0].write(l:in . s:get_complete_key())

  " Get output.
  let l:read = b:vimproc_sub[0].read(-1, 40)
  let l:output = ''
  while !vimshell#head_match(split(l:output, '\r\n\|\n', 1)[-1], l:prompt)
    let l:output .= l:read

    let l:read = b:vimproc_sub[0].read(-1, 40)
  endwhile

  if &termencoding != '' && &encoding != &termencoding
    " Convert encoding.
    let l:output = iconv(l:output, &termencoding, &encoding)
  endif

  let l:candidates = split(join(split(l:output, '\r\n\|\n')[1: -2], '  '), '\s\s\+')
  let l:cnt = 0
  let l:ignore_input = l:in[: -len(a:cur_keyword_str)-1]
  for l:candidate in l:candidates
    if vimshell#head_match(l:candidate, l:ignore_input)
      " Delete input line.
      let l:candidates[l:cnt] = l:candidate[len(l:ignore_input) :]
    endif

    let l:cnt += 1
  endfor 

  " Delete input.
  call b:vimproc_sub[0].write(repeat("\<C-h>", len(l:in)))

  return vimshell#complete#helper#keyword_filter(l:candidates, a:cur_keyword_str)
endfunction"}}}

function! s:get_complete_key()"{{{
  if !vimshell#iswin()
    " For pty program.
    return "\<TAB>"
  elseif &filetype == 'iexe_zsh' || &filetype == 'iexe_nyaos' 
    return "\<C-d>"
  else
    " For readline program.
    return "\<ESC>?"
  endif
endfunction"}}}
" vim: foldmethod=marker
