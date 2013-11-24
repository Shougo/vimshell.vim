"=============================================================================
" FILE: helpers.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 24 Nov 2013.
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

let s:save_cpo = &cpo
set cpo&vim

function! vimshell#helpers#get_editor_name() "{{{
  if !exists('g:vimshell_editor_command')
    " Set editor command.
    if has('clientserver') && (has('gui_running') || has('gui'))
      let g:vimshell_editor_command = g:vimshell_cat_command

      if has('gui_macvim')
        " MacVim check.
        if executable('/Applications/MacVim.app/Contents/MacOS/Vim')
          let progname = 'Applications/MacVim.app/Contents/MacOS/Vim'
        elseif executable(expand('~/Applications/MacVim.app/Contents/MacOS/Vim'))
          let progname = expand('~/Applications/MacVim.app/Contents/MacOS/Vim')
        else
          echoerr 'You installed MacVim in not default directory!'.
                \ ' You must set g:vimshell_editor_command manually.'
          return g:vimshell_cat_command
        endif

        let progname = '/Applications/MacVim.app/Contents/MacOS/Vim'
      else
        let progname = has('gui_running') ? v:progname : 'vim'
      endif

      let progname .= ' -g'

      let g:vimshell_editor_command = printf('%s %s --remote-tab-wait-silent',
            \ progname, (v:servername == '' ? '' : ' --servername='.v:servername))
    endif
  endif

  return g:vimshell_editor_command
endfunction"}}}
function! vimshell#helpers#execute_internal_command(command, args, context) "{{{
  if empty(a:context)
    let context = { 'has_head_spaces' : 0, 'is_interactive' : 1 }
  else
    let context = a:context
  endif

  if !has_key(context, 'fd') || empty(context.fd)
    let context.fd = { 'stdin' : '', 'stdout' : '', 'stderr' : '' }
  endif

  let internal = vimshell#init#_internal_commands(a:command)
  if empty(internal)
    call vimshell#error_line(context.fd,
          \ printf('Internal command : "%s" is not found.', a:command))
    return
  elseif internal.kind ==# 'execute'
    " Convert args.
    let args = type(get(a:args, 0, '')) == type('') ?
          \ [{ 'args' : a:args, 'fd' : context.fd}] : a:args
    return internal.execute(args, context)
  else
    return internal.execute(a:args, context)
  endif
endfunction"}}}
function! vimshell#helpers#imdisable() "{{{
  " Disable input method.
  if exists('g:loaded_eskk') && eskk#is_enabled()
    call eskk#disable()
  elseif exists('b:skk_on') && b:skk_on && exists('*SkkDisable')
    call SkkDisable()
  elseif exists('&iminsert')
    let &l:iminsert = 0
  endif
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
