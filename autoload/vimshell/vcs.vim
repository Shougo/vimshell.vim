"=============================================================================
" FILE: vcs.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 25 Dec 2009
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
"=============================================================================

if !exists('g:vimshell_vcs_print_null')
  let g:vimshell_vcs_print_null = 0
endif

function! vimshell#vcs#info(string, ...)"{{{
    let func_name = s:load_vcs_plugin()
    if func_name == ''
        return g:vimshell_vcs_print_null ? '[novcs]-(noinfo)' : ''
    endif

    if call(func_name . 'action_message', []) != '' && !empty(a:000)
        " Use action format.
        let format_string = a:1
    else
        let format_string = a:string
    endif
    
    " Substitute format string.
    let cnt = 0
    let max = len(format_string)
    let info = ''
    while cnt < max
        if format_string[cnt] == '%' && cnt+1 < max
            let format = format_string[cnt + 1]
            if format == '%'
                " %%.
                let info .= '%'
            elseif format == 's'
                " %s : VCS name.
                let info .= call(func_name . 'vcs_name', [])
            elseif format == 'b'
                " %b : current branch name.
                let info .= call(func_name . 'current_branch', [])
            elseif format == 'r'
                " %r : repository name.
                let info .= call(func_name . 'repository_name', [])
            elseif format == 'R'
                " %R : path to repository root.
                let info .= call(func_name . 'repository_root_path', [])
            elseif format == 'S'
                " %s : relative path to root.
                let info .= call(func_name . 'repository_relative_path', [])
            elseif format == 'a'
                " %s : action message.
                let info .= call(func_name . 'action_message', [])
            else
                " Ignore.
                let info .= '?'
            endif
            
            let cnt += 1
        else
            let info .= format_string[cnt]
        endif
        
        let cnt += 1
    endwhile

    return info
endfunction"}}}

function! s:load_vcs_plugin()"{{{
    " Load VCS plugins.
    " Search autoload.
    let func_list = split(globpath(&runtimepath, 'autoload/vimshell/vcs/*.vim'), '\n')
    for list in func_list
        let func_name = 'vimshell#vcs#' . fnamemodify(list, ':t:r') . '#'
        if call(func_name . 'is_vcs_dir', [])
            return func_name
        endif
    endfor
    
    return ''
endfunction"}}}
" vim: foldmethod=marker
