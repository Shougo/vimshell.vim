"=============================================================================
" FILE: cd.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
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

function! vimshell#internal#cd#execute(program, args, fd, other_info)
  " Change the working directory.

  if empty(a:args)
    " Move to HOME directory.
    let l:dir = $HOME
  elseif len(a:args) == 2
    " Substitute current directory.
    let l:dir = substitute(getcwd(), a:args[0], a:args[1], 'g')
  elseif len(a:args) > 2
    call vimshell#error_line(a:fd, 'Too many arguments.')
    return
  else
    " Filename escape.
    let l:dir = substitute(a:args[0], '^\~\ze[/\\]', substitute($HOME, '\\', '/', 'g'), '')
  endif

  if empty(b:vimshell.directory_stack) || getcwd() != b:vimshell.directory_stack[0]
    " Push current directory.
    call insert(b:vimshell.directory_stack, getcwd())
  endif

  if isdirectory(l:dir)
    " Move to directory.
    let b:vimshell.save_dir = fnamemodify(l:dir, ':p')
    lcd `=b:vimshell.save_dir`
  elseif l:arguments == '-'
    " Popd.
    return vimshell#internal#popd#execute('popd', [ 1 ], 
          \ a:fd,
          \ { 'has_head_spaces' : 0, 'is_interactive' : 1 })
  elseif filereadable(l:dir)
    " Move to parent directory.
    let b:vimshell.save_dir = fnamemodify(l:dir, ':p:h')
    lcd `=b:vimshell.save_dir`
  else
    " Check cd path.
    let l:dirs = split(globpath(&cdpath, l:dir), '\n')
    if !empty(l:dirs) && isdirectory(l:dirs[0])
      let b:vimshell.save_dir = fnamemodify(l:dirs[0], ':p')
      lcd `=b:vimshell.save_dir`
    else
      call vimshell#error_line(a:fd, printf('File "%s" is not found.', l:arguments))

      if getcwd() == b:vimshell.directory_stack[0]
        " Restore directory.
        let b:vimshell.directory_stack = b:vimshell.directory_stack[1:]
      endif
    endif
  endif
  
  if a:other_info.is_interactive
    " Call chpwd hook.
    let l:context = a:other_info
    let l:context.fd = a:fd
    for l:func_name in values(b:vimshell.hook_functions_table['chpwd'])
      call call(l:func_name, [l:context])
    endfor
  endif
endfunction
