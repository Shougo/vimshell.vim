"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Janakiraman .S <prince@india.ti.com>(Original)
"         Shougo Matsushita <Shougo.Matsu@gmail.com>(Modified)
" Last Modified: 05 Jul 2009
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
" Version: 5.22, for Vim 7.0
"-----------------------------------------------------------------------------
" ChangeLog: "{{{
"   5.22 :
"     - Improved share history.
"     - Improved run_help.
"     - Improved alias.
"
"   5.21 :
"     - Improved error highlight.
"     - Implemented password input.
"     - Implemented sudo internal command.
"     - Added g:VimShell_SecondaryPrompt option.
"     - Set COLUMNS and LINES environment variables.
"     - Remove dup history.
"     - Improved history commands.
"     - Splitted parser.
"     - Reduce blanks when append history.
"     - Implemented insert last word keymapping.
"     - Improved iexe.
"     - Implemented run_help.
"
"   5.20 :
"     - Added g:VimShell_UsePopen2 option.
"     - Openable directory in vim command.
"     - Improved bg command.
"     - Fixed escape sequence.
"     - Improved highlight timing.
"     - Implemented error highlight.
"     - Refactoringed interactive.vim.
"
"   5.19 :
"     - Improved variables path.
"     - Implemented "h string".
"     - Added space when command completed.
"     - Improved escape sequence support.
"
"   5.18 :
"     - Improved command completion.
"     - Changed alias syntax.
"     - Improved stdin read.
"     - Improved pipe in external command.
"
"   5.17 :
"     - Fixed error when bg or iexe terminated.
"     - Implemented gexe command.
"     - Implemented pipe.
"     - Check pipe in ls command.
"     - Improved wildcard.
"     - Fully pipe implemented.
"
"   5.16 :
"     - Implemented back quote and vim quote.
"     - Implemented double quote escape.
"     - Implemented expand home directory.
"     - Fixed stdin redirection bug.
"     - Get status.
"
"   5.15 :
"     - Fixed for ATOK X3.
"     - Improved error catch.
"     - Implemented redirection.
"     - Implemented /dev/null virtual device.
"     - Implemented special functions.
"     - Improved let and ev.
"
"   5.14 :
"     - Implemented echo.
"     - Implemented wildcard.
"     - Executable one liner in Windows.
"     - Improved command search.
"     - Implemented command completion.
"     - Fixed g:VimShell_ExecuteFileList bug.
"
"   5.13 :
"     - Added command vimshell_delete_previous_prompt.
"     - Fixed lcd escape bug.
"     - Deleted process.vim.
"     - Deleted ! execution.
"     - Added gcd command.
"     - Optimized parse in alias and let commands.
"
"   5.12 Changed command behaivior:
"     - Added g:VimShell_EnableInteractive option.
"     - Changed command behaivior.
"     - Added exe command.
"     - Convert encoding for system().
"     - Fixed name conversion.
"     - Added g:VimShell_SplitHeight option.
"
"   5.11:
"     - Added VimShellExecute and VimShellInteractive commands.
"
"   5.10:
"     - Implemented iexe.
"     - Improved bg.
"     - Improved print_prompt().
"     - Use neocomplcache#manual_filename_complete().
"
"   Ver.5.9 ~ 4.0"{{{
"   5.9:
"     - Fixed background execution.
"     - Fixed auto_cd bug.
"     - Fixed error in screen command.
"
"   5.8:
"     - Fixed !! error.
"     - Implemented filename completion.
"     - Implemented exchange ~ into $HOME.
"
"   5.7:
"     - Implemented g:VimShell_ExecuteFileList.
"     - Refactoring.
"     - Added screen, bg internal command.
"
"   5.6:
"     - Escape prompt when prompt search.
"     - Fixed auto cd error.
"
"   5.5:
"     - Created ftplugin/vimshell.vim
"     - Added command vimshell_previous_prompt and vimshell_next_prompt.
"
"   5.4:
"     - Fixed alias, cd, histdel bug.
"
"   5.3:
"     - Improved autocmds.
"     - Refactoring plugin call.
"
"   5.2:
"     - Plugin interface changed.
"     - Converted special commands into internal commands.
"     - Deleted quick match.
"
"   5.1:
"     - Improved key-mappings and autocmd.
"     - Implemented command line stack.
"
"   5.0:
"     - Return previous buffer when call vimshell#switch_shell on vimshell.
"     - Implemented vimshell#error_line.
"     - Error when iexe execute without python interface.
"
"   4.9:
"     - Implemented exit command.
"     - Implemented hide command.
"     - Added g:VimShell_SmartCase option.
"
"   4.8:
"     - Implemented comment.
"     - Not escape when cd command.
"     - Eval environment variables.
"
"   4.7:
"     - Improved vimshell#switch_shell.
"     - Implemented one command.
"     - Implemented ev command.
"
"   4.6:
"     - Implemented h command.
"     - Implemented VimShell buffer current directory.
"     - History execution was implemented with h command.
"     - Change VimShell current directory when vimshell#switch_shell.
"
"   4.5:
"     - Fixed popd and history bugs.
"     - Implemented history arguments.
"     - Implemented internal command.
"     - Improved syntax color.
"
"   4.4:
"     - Changed s:alias_table into b:vimshell_alias_table.
"     - Interpret cd of no argument as cd $HOME
"     - Added pwd command.
"     - Improved ls on Windows.
"     - Load ~/.vimshrc on init.
"     - Improved escape.
"
"   4.3:
"     - Implemented zsh like cd.
"     - Make built-in command autoload.
"     - Optimized special commands.
"     - Implemented popd, dirs command.
"
"   4.2:
"     - Implemented alias command.
"     - Implemented VimShell script.
"     - Optimized vimshell#process_enter.
"
"   4.1:
"     - Implemented history command.
"     - Implemented histdel command.
"     - Implemented nop command.
"     - Ignore empty command line.
"
"   4.0:
"     - Implemented shell background execution.
"     - Added g:VimShell_UseCkw option."}}}
"   Ver.3.9 ~ 1.0"{{{
"   3.9:
"     - Implemented background execution on Linux.
"     - Improved print prompt.
"     - Fixed cd bug.
"     - Fixed background execution bug.
"   3.8:
"     - Implemented background execution on Windows.
"     - Implemented shell execution.
"     - Implemented shell command.
"     - Implemented exit command.
"   3.7:
"     - Not escape quotation.
"     - Implemented command completion.
"   3.6:
"     - Improved command execute.
"     - Fixed execute program bug.
"   3.5:
"     - Implemented by autoload.
"     - Fixed non-Windows platform error.
"     - Improved history executed.
"     - Fixed many bugs.
"   3.4:
"     - Fixed filename escape bug.
"     - Fixed vimshell buffer clear when hide.
"     - No setlocal lazyredraw.
"     - Filename escape when cd.
"     - Implemented pseudo shell variables.
"   3.3:
"     - Changed escape sequence into "\<ESC>".
"     - Changed autocmd timing.
"     - Added filename escape.
"     - Added vimshell_split_switch, vimshell_switch, vimshell_split_create, vimshell_create.
"     - Can have multiple Vimshell instance.
"   3.2:
"     - Fixed space name command bug.
"     - Fixed quick match bug.
"     - Implemented vim and view command.
"   3.1:
"     - Fixed ATOK X3 is ON  when startinsert.
"     - Silent message if exit code isn't 0.
"   3.0:
"     - Do startinsert! after command executed.
"     - Added g:VimShell_QuickMatchMaxLists option.
"     - Added g:VimShell_QuickMatchEnable option.
"     - Implemented two digits quick match.
"   2.9:
"     - Trial implemented highlight escape sequence.
"     - Fixed history bug.
"     - Convert cd to lcd.
"   2.8:
"     - Dup check when quick match.
"     - Due to optimize, filtering len(cur_keyword_str) >.
"     - Ignore head spaces when completion.
"   2.7:
"     - Implemented shell history completion by omnifunc.
"     - Mapping omnifunc <C-j>.
"     - Implemented quick match.
"     - Improved escape.
"   2.6:
"     - Implemented shell history.
"   2.5:
"     - Set lazyredraw in vimshell buffer.
"     - Refactoring.
"   2.3:
"     - Code cleanup.
"   2.2:
"     - Fix syntax highlight at pipe command.
"     - Fix quotation highlight.
"   2.1:
"     - Fix syntax highlights.
"   2.0:
"     - Implemented syntax highlight.
"   1.0:
"     - Initial version."}}}
""}}}
"-----------------------------------------------------------------------------
" TODO: "{{{
"     -
""}}}
" Bugs"{{{
"     -
""}}}
"=============================================================================

if exists('g:loaded_vimshell') || v:version < 700
  finish
endif

" Plugin keymapping"{{{
nnoremap <silent> <Plug>(vimshell_split_switch)  :<C-u>call vimshell#switch_shell(1)<CR>
nnoremap <silent> <Plug>(vimshell_split_create)  :<C-u>call vimshell#create_shell(1)<CR>
nnoremap <silent> <Plug>(vimshell_switch)  :<C-u>call vimshell#switch_shell(0)<CR>
nnoremap <silent> <Plug>(vimshell_create)  :<C-u>call vimshell#create_shell(0)<CR>
nnoremap <silent> <Plug>(vimshell_enter)  :<C-u>call vimshell#process_enter()<CR>
inoremap <silent> <Plug>(vimshell_insert_command_completion)  <ESC>:<C-u>call vimshell#insert_command_completion()<CR>a<C-x><C-o>
inoremap <silent> <Plug>(vimshell_push_current_line)  <ESC>:<C-u>call vimshell#push_current_line()<CR>
inoremap <silent> <Plug>(vimshell_insert_last_word)  <ESC>:<C-u>call vimshell#insert_last_word()<CR>
inoremap <silent> <Plug>(vimshell_run_help)  <ESC>:<C-u>call vimshell#run_help()<CR>
nnoremap <silent> <Plug>(vimshell_previous_prompt)  :<C-u>call vimshell#previous_prompt()<CR>
nnoremap <silent> <Plug>(vimshell_next_prompt)  :<C-u>call vimshell#next_prompt()<CR>
nnoremap <silent> <Plug>(vimshell_delete_previous_prompt)  :<C-u>call vimshell#delete_previous_prompt()<CR>
nmap <silent> <Leader>sp     <Plug>(vimshell_split_switch)
nmap <silent> <Leader>sn     <Plug>(vimshell_split_create)
nmap <silent> <Leader>sh     <Plug>(vimshell_switch)
nmap <silent> <Leader>sc     <Plug>(vimshell_create)
"}}}

" Global options definition."{{{
if !exists('g:VimShell_Prompt')
    let g:VimShell_Prompt = 'VimShell% '
endif
if !exists('g:VimShell_SecondaryPrompt')
    let g:VimShell_SecondaryPrompt = '%% '
endif
if !exists('g:VimShell_HistoryPath')
    if has('win32') || has('win64')
        let g:VimShell_HistoryPath = $HOME.'\.vimshell_hist'
    else
        let g:VimShell_HistoryPath = $HOME.'/.vimshell_hist'
    endif
endif
if !exists('g:VimShell_HistoryMaxSize')
    let g:VimShell_HistoryMaxSize = 1000
endif
if !exists('g:VimShell_VimshrcPath')
    if has('win32') || has('win64')
        let g:VimShell_VimshrcPath = $HOME.'\.vimshrc'
    else
        let g:VimShell_VimshrcPath = $HOME.'/.vimshrc'
    endif
endif
if !exists('g:VimShell_IgnoreCase')
    let g:VimShell_IgnoreCase = 1
endif
if !exists('g:VimShell_SmartCase')
    let g:VimShell_SmartCase = 0
endif
if !exists('g:VimShell_MaxHistoryWidth')
    let g:VimShell_MaxHistoryWidth = 40
endif
if !exists('g:VimShell_UseCkw')
    let g:VimShell_UseCkw = 0
endif
if !exists('g:VimShell_ExecuteFileList')
    let g:VimShell_ExecuteFileList = {}
endif
if !exists('g:VimShell_EnableInteractive')
    let g:VimShell_EnableInteractive = 0
endif
if !exists('g:VimShell_SplitHeight')
    let g:VimShell_SplitHeight = 30
endif
if !exists('g:VimShell_UsePopen2')
    let g:VimShell_UsePopen2 = 0
endif
"}}}

command! -nargs=0 VimShell call vimshell#switch_shell(0)
command! -nargs=+ -complete=shellcmd VimShellExecute call vimshell#internal#bg#vimshell_bg(split(<q-args>))
command! -nargs=+ -complete=shellcmd VimShellInteractive call vimshell#internal#iexe#vimshell_iexe(split(<q-args>))

let g:loaded_vimshell = 1

" vim: foldmethod=marker
