"=============================================================================
" FILE: interactive.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 15 Feb 2009
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
" Version: 1.01, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   1.01:
"     - Compatible Windows and Linux.
"   1.00:
"     - Initial version.
" }}}
"-----------------------------------------------------------------------------
" TODO: "{{{
"     - Nothing.
""}}}
" Bugs"{{{
"     - Nothing.
""}}}
"=============================================================================
"
function! interactive#async_callback(res)
    call append(line('$'), split(a:res, "\n"))
    redraw
endfunction
if has('win32') || has('win64')
    " For Windows.
    function! interactive#run(command) " {{{
        let g:async_command=a:command

python << EOP
import vim
import thread
import nt as os

def run():
    command = vim.eval('g:async_command')
    fr = os.popen(command, 'r')
    result = fr.read()
    fr.close()
    vim.eval("interactive#async_callback('" + result + "')")

thread.start_new_thread(run, ())
EOP
    endfunction
    " }}}
else
    " For Linux.
    function! interactive#run(command) " {{{
        let g:async_command=a:command

python << EOP
import vim
import thread
import commands

def run():
    command = vim.eval('g:async_command')
    result = commands.getoutput(command)
    vim.eval("interactive#async_callback('" + result + "')")

thread.start_new_thread(run, ())
EOP
    endfunction
    " }}}
endif
" vim: foldmethod=marker
