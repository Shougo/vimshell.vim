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
    let l:func_name = s:load_vcs_plugin()
    if l:func_name == ''
        return g:vimshell_vcs_print_null ? '[novcs]-(noinfo)' : ''
    endif

    if call(l:func_name . 'action_message', []) != '' && !empty(a:000)
        " Use action format.
        let l:format_string = a:1
    else
        let l:format_string = a:string
    endif
    
    " Substitute format string.
    let l:cnt = 0
    let l:max = len(l:format_string)
    let l:info = ''
    while l:cnt < l:max
        if l:format_string[l:cnt] == '%' && l:cnt+1 < l:max
            let l:format = l:format_string[l:cnt + 1]
            if l:format == '%'
                " %%.
                let l:info .= '%'
            elseif l:format == 's'
                " %s : VCS name.
                let l:info .= call(l:func_name . 'vcs_name', [])
            elseif l:format == 'b'
                " %b : current branch name.
                let l:info .= call(l:func_name . 'current_branch', [])
            elseif l:format == 'r'
                " %r : repository name.
                let l:info .= call(l:func_name . 'repository_name', [])
            elseif l:format == 'R'
                " %R : path to repository root.
                let l:info .= call(l:func_name . 'repository_root_path', [])
            elseif l:format == 'S'
                " %s : relative path to root.
                let l:info .= call(l:func_name . 'repository_relative_path', [])
            elseif l:format == 'a'
                " %s : action message.
                let l:info .= call(l:func_name . 'action_message', [])
            else
                " Ignore.
                let l:info .= '?'
            endif
            
            let l:cnt += 1
        else
            let l:info .= l:format_string[l:cnt]
        endif
        
        let l:cnt += 1
    endwhile

    return l:info
endfunction"}}}

function! s:load_vcs_plugin()"{{{
    " Load VCS plugins.
    " Search autoload.
    let l:func_list = split(globpath(&runtimepath, 'autoload/vimshell/vcs/*.vim'), '\n')
    for list in l:func_list
        let l:func_name = 'vimshell#vcs#' . fnamemodify(list, ':t:r') . '#'
        if call(l:func_name . 'is_vcs_dir', [])
            return l:func_name
        endif
    endfor
    
    return ''
endfunction"}}}
" vim: foldmethod=marker
