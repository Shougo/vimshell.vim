"=============================================================================
" FILE: cd.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 07 Oct 2010
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
      \ 'name' : 'cd',
      \ 'kind' : 'internal',
      \ 'description' : 'cd {directory-path} [{substitute-pattern}]',
      \}
function! s:command.execute(command, args, fd, context)"{{{
  " Change the working directory.

  if empty(a:args)
    " Move to HOME directory.
    let l:dir = $HOME
  elseif len(a:args) == 2
    " Substitute current directory.
    let l:dir = substitute(getcwd(), a:args[0], a:args[1], 'g')
  elseif len(a:args) > 2
    call vimshell#error_line(a:fd, 'cd: Too many arguments.')
    return
  else
    " Filename escape.
    let l:dir = substitute(a:args[0], '^\~\ze[/\\]', substitute($HOME, '\\', '/', 'g'), '')
  endif

  if vimshell#iswin()
    let l:dir = vimshell#resolve(l:dir)
  endif

  let l:cwd = getcwd()
  if isdirectory(l:dir)
    " Move to directory.
    let b:vimshell.save_dir = fnamemodify(l:dir, ':p')
    call vimshell#cd(b:vimshell.save_dir)
  elseif l:dir =~ '^-\d*$'
    " Popd.
    return vimshell#execute_internal_command('popd', [ l:dir[1:] ], 
          \ a:fd,
          \ { 'has_head_spaces' : 0, 'is_interactive' : 1 })
  elseif filereadable(l:dir)
    " Move to parent directory.
    let b:vimshell.save_dir = fnamemodify(l:dir, ':p:h')
    call vimshell#cd(b:vimshell.save_dir)
  else
    " Check cd path.
    let l:dirs = split(globpath(&cdpath, l:dir), '\n')

    if empty(l:dirs)
      call vimshell#error_line(a:fd, printf('cd: File "%s" is not found.', l:dir))
      return
    endif

    if vimshell#iswin()
      let l:dir = vimshell#resolve(l:dir)
    endif

    if isdirectory(l:dirs[0])
      let b:vimshell.save_dir = fnamemodify(l:dirs[0], ':p')
      call vimshell#cd(b:vimshell.save_dir)
    else
      call vimshell#error_line(a:fd, printf('cd: File "%s" is not found.', l:dir))
      return
    endif
  endif

  if empty(b:vimshell.directory_stack) || getcwd() != b:vimshell.directory_stack[0]
    " Push current directory and filtering.
    call insert(filter(b:vimshell.directory_stack, 'v:val != ' . string(l:cwd)), l:cwd)

    " Truncate.
    let b:vimshell.directory_stack = b:vimshell.directory_stack[: g:vimshell_max_directory_stack-1]
  endif

  if a:context.is_interactive
    " Call chpwd hook.
    let l:context = a:context
    let l:context.fd = a:fd
    call vimshell#hook#call('chpwd', l:context)
  endif
endfunction"}}}
function! s:command.complete(args)"{{{
  if a:args[-1] =~ '^-\d*$'
    let l:ret = vimshell#complete#helper#directory_stack(a:args[-1][1:])
    for l:keyword in l:ret
      let l:keyword.abbr = l:keyword.word
      let l:keyword.word = '-' . l:keyword.word
    endfor
  else
    let l:ret = vimshell#complete#helper#directories(a:args[-1])
  endif
    
  return l:ret
endfunction"}}}

function! vimshell#commands#cd#define()
  return s:command
endfunction
