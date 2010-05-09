"=============================================================================
" FILE: open.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 09 May 2010
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

function! vimshell#internal#open#execute(program, args, fd, other_info)"{{{
  " Open file.

  " Detect desktop environment.
  if vimshell#iswin()
    let l:filename = join(a:args)
    if &termencoding != '' && &encoding != &termencoding
      " Convert encoding.
      let l:filename = iconv(l:filename, &encoding, &termencoding)
    endif

    if executable('cmdproxy.exe') && exists('*vimproc#system')
      " Use vimproc.
      call vimproc#system(printf('cmdproxy /C "start \"\" \"%s\""', l:filename))
    else
      execute printf('silent ! start "" "%s"', l:filename)
    endif
    return 0
  elseif exists('$KDE_FULL_SESSION') && $KDE_FULL_SESSION ==# 'true'
    " KDE.
    let l:args = ['kioclient', 'exec'] + a:args
  elseif exists('$GNOME_DESKTOP_SESSION_ID')
    " GNOME.
    let l:args = ['gnome-open'] + a:args
  elseif executable('exo-open')
    " Xfce.
    let l:args = ['exo-open'] + a:args
  elseif (has('macunix') || system('uname') =~? '^darwin') && executable('open')
    let l:args = ['open'] + a:args
  else
    throw 'open: Not supported.'
  endif

  return vimshell#execute_internal_command('gexe', l:args, a:fd, a:other_info)
endfunction"}}}

