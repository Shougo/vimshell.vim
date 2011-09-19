"=============================================================================
" FILE: view.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 17 Nov 2010
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

let s:command = {
      \ 'name' : 'view',
      \ 'kind' : 'internal',
      \ 'description' : 'view [{filename}]',
      \}
function! s:command.execute(program, args, fd, context)"{{{
  let [l:args, l:options] = vimshell#parser#getopt(a:args, {
        \ 'arg=' : ['--split'],
        \ }, {
        \ '--split' : g:vimshell_split_command,
        \ })

  if empty(l:args)
    if a:fd.stdin == ''
      vimshell#error_line(a:fd, 'view: Filename required.')
      return
    endif

    " Read from stdin.
    let l:filenames = [a:fd.stdin]
  else
    let l:filenames = l:args
  endif

  if len(l:filenames) == 1 && !isdirectory(l:filenames[0])
    let l:lines = readfile(l:filenames[0])
    if len(l:lines) < winheight(0)
      " Print lines if one screen.
      for l:line in l:lines
        call vimshell#print_line(a:fd, l:line)
      endfor

      return
    endif
  endif

  " Save current directiory.
  let l:cwd = getcwd()

  let [l:new_pos, l:old_pos] = vimshell#split(l:options['--split'])

  for l:filename in l:filenames
    try
      silent edit +setlocal\ readonly `=l:filename`
    catch
      echohl Error | echomsg v:errmsg | echohl None
    endtry
  endfor

  let [l:new_pos[2], l:new_pos[3]] = [bufnr('%'), getpos('.')]

  call vimshell#cd(l:cwd)

  call vimshell#restore_pos(l:old_pos)

  if has_key(a:context, 'is_single_command') && a:context.is_single_command
    call vimshell#next_prompt(a:context, 0)
    call vimshell#restore_pos(l:new_pos)
    stopinsert
  endif
endfunction"}}}

function! vimshell#commands#view#define()
  return s:command
endfunction
