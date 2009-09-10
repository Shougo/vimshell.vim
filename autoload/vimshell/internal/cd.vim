"=============================================================================
" FILE: cd.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 10 Sep 2009
" Usage: Just source this file.
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
" Version: 1.9, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.9:
"     - Implemented 'cd -'.
"     - Implemented 'cd name1 name2'.
"
"   1.8:
"     - Check cd path.
"
"   1.7:
"     - Improved pushd timing.
"
"   1.6:
"     - Move to parent directory if argument isn't directory.
"
"   1.5:
"     - Implemented exchange ~ into $HOME.
"
"   1.4:
"     - Fixed error.
"
"   1.3:
"     - Supported vimshell Ver.3.2.
"
"   1.2:
"     - Improved escape sequence.
"
"   1.1:
"     - Interpret cd of no argument as cd $HOME
"
"   1.0:
"     - Initial version.
""}}}
"-----------------------------------------------------------------------------
" TODO: "{{{
"     - Nothing.
""}}}
" Bugs"{{{
"     -
""}}}
"=============================================================================

function! vimshell#internal#cd#execute(program, args, fd, other_info)
    " Change the working directory.

    if empty(a:args)
        " Move to HOME directory.
        let l:arguments = $HOME
    elseif len(a:args) == 2
        " Substitute current directory.
        let l:arguments = substitute(getcwd(), a:args[0], a:args[1], 'g')
    elseif len(a:args) > 2
        call vimshell#error_line(a:fd, 'Too many arguments.')
        return
    else
        " Filename escape.
        let l:arguments = substitute(a:args[0], '^\~\ze[/\\]', substitute($HOME, '\\', '/', 'g'), '')
    endif

    if empty(w:vimshell_directory_stack) || getcwd() != w:vimshell_directory_stack[0]
        " Push current directory.
        call insert(w:vimshell_directory_stack, getcwd())
    endif

    if isdirectory(l:arguments)
        " Move to directory.
        lcd `=fnamemodify(l:arguments, ':p')`
    elseif l:arguments == '-'
        " Popd.
        return vimshell#internal#popd#execute('popd', [ 1 ], 
                    \{ 'stdin' : '', 'stdout' : '', 'stderr' : '' },
                    \{ 'has_head_spaces' : 0, 'is_interactive' : 1, 'is_background' : 0 })
    elseif filereadable(l:arguments)
        " Move to parent directory.
        lcd `=fnamemodify(l:arguments, ':p:h')`
    else
        " Check cd path.
        let l:dirs = split(globpath(&cdpath, l:arguments), '\n')
        if !empty(l:dirs) && isdirectory(l:dirs[0])
            lcd `=fnamemodify(l:dirs[0], ':p')`
        else
            call vimshell#error_line(a:fd, printf('File "%s" is not found.', l:arguments))
        endif
    endif
endfunction
