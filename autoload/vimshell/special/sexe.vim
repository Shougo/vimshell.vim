"=============================================================================
" FILE: sexe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 05 May 2010
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

function! vimshell#special#sexe#execute(program, args, fd, other_info)"{{{
  let [l:args, l:options] = vimshell#parser#getopt(a:args, 
        \{ 'arg=' : ['--encoding']
        \})
  if !has_key(l:options, '--encoding')
    let l:options['--encoding'] = &termencoding
  endif

  " Execute shell command.
  let l:iswin = has('win32') || has('win64')
  let l:cmdline = ''
  for arg in l:args
    if l:iswin
      let l:arg = substitute(arg, '"', '\\"', 'g')
      let l:arg = substitute(arg, '[<>|^]', '^\0', 'g')
      let l:cmdline .= '"' . arg . '" '
    else
      let l:cmdline .= shellescape(arg) . ' '
    endif
  endfor

  if l:iswin
    let l:cmdline = '"' . l:cmdline . '"'
  endif

  " Set redirection.
  if a:fd.stdin == ''
    let l:stdin = ''
  elseif a:fd.stdin == '/dev/null'
    let l:null = tempname()
    call writefile([], l:null)

    let l:stdin = '<' . l:null
  else
    let l:stdin = '<' . a:fd.stdin
  endif

  echo 'Running command.'
  
  if l:options['--encoding'] != '' && &encoding != l:options['--encoding']
    " Convert encoding.
    let l:cmdline = iconv(l:cmdline, &encoding, l:options['--encoding'])
    let l:stdin = iconv(l:stdin, &encoding, l:options['--encoding'])
  endif
  let l:result = system(printf('%s %s', l:cmdline, l:stdin))
  if l:options['--encoding'] != '' && &encoding != l:options['--encoding']
    " Convert encoding.
    let l:result = iconv(l:result, l:options['--encoding'], &encoding)
  endif
  
  call vimshell#print(a:fd, l:result)
  redraw
  echo ''

  if a:fd.stdin == '/dev/null'
    call delete(l:null)
  endif

  let b:vimshell.system_variables['status'] = v:shell_error

  return
endfunction"}}}

