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
function! s:command.execute(args, context)"{{{
  " Change the working directory.

  if empty(a:args)
    " Move to HOME directory.
    let dir = $HOME
  elseif len(a:args) == 2
    " Substitute current directory.
    let dir = substitute(getcwd(), a:args[0], a:args[1], 'g')
  elseif len(a:args) > 2
    call vimshell#error_line(a:context.fd, 'cd: Too many arguments.')
    return
  else
    " Filename escape.
    let dir = substitute(a:args[0], '^\~\ze[/\\]', substitute($HOME, '\\', '/', 'g'), '')
  endif

  if vimshell#iswin()
    let dir = vimshell#resolve(dir)
  endif

  let cwd = getcwd()
  if isdirectory(dir)
    " Move to directory.
    let b:vimshell.current_dir = fnamemodify(dir, ':p')
    call vimshell#cd(b:vimshell.current_dir)
  elseif dir =~ '^-\d*$'
    " Popd.
    return vimshell#execute_internal_command('popd', [ dir[1:] ],
          \ { 'has_head_spaces' : 0, 'is_interactive' : 1 })
  elseif filereadable(dir)
    " Move to parent directory.
    let b:vimshell.current_dir = fnamemodify(dir, ':p:h')
    call vimshell#cd(b:vimshell.current_dir)
  else
    " Check cd path.
    let dirs = split(globpath(&cdpath, dir), '\n')

    if empty(dirs)
      call vimshell#error_line(a:context.fd, printf('cd: File "%s" is not found.', dir))
      return
    endif

    if vimshell#iswin()
      let dir = vimshell#resolve(dir)
    endif

    if isdirectory(dirs[0])
      let b:vimshell.current_dir = fnamemodify(dirs[0], ':p')
      call vimshell#cd(b:vimshell.current_dir)
    else
      call vimshell#error_line(a:context.fd, printf('cd: File "%s" is not found.', dir))
      return
    endif
  endif

  if empty(b:vimshell.directory_stack) || cwd !=# b:vimshell.directory_stack[0]
    " Push current directory and filtering.
    call insert(b:vimshell.directory_stack, cwd)

    " Truncate.
    let b:vimshell.directory_stack = b:vimshell.directory_stack[: g:vimshell_max_directory_stack-1]
  endif

  if a:context.is_interactive
    " Call chpwd hook.
    let context = a:context
    let context.fd = a:context.fd
    call vimshell#hook#call('chpwd', context, getcwd())
  endif
endfunction"}}}
function! s:command.complete(args)"{{{
  if a:args[-1] =~ '^-\d*$'
    let ret = vimshell#complete#helper#directory_stack(a:args[-1][1:])
    for keyword in ret
      let keyword.abbr = keyword.word
      let keyword.word = '-' . keyword.word
    endfor
  else
    let ret = vimshell#complete#helper#directories(a:args[-1])
  endif
    
  return ret
endfunction"}}}

function! vimshell#commands#cd#define()
  return s:command
endfunction
