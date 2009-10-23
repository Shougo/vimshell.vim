" Key mappings.
" 

" Normal mode key-mappings.""{{{
" Execute command.
nmap <buffer> <CR> <Plug>(vimshell_enter)
" Hide vimshell.
nmap <buffer> q <Plug>(vimshell_hide)
" Move to previous prompt.
nmap <buffer> <C-p> <Plug>(vimshell_previous_prompt)
" Move to next prompt.
nmap <buffer> <C-n> <Plug>(vimshell_next_prompt)
" Remove this output.
nmap <buffer> <C-d> <Plug>(vimshell_delete_previous_output)
" Paste this prompt.
nmap <buffer> <C-y> <Plug>(vimshell_paste_prompt)
" Search end argument.
nmap <buffer> E <Plug>(vimshell_move_end_argument)
"}}}

" Insert mode key-mappings."{{{
" Execute command.
imap <buffer> <CR> <ESC><Plug>(vimshell_enter)
" History completion.
imap <buffer> <C-j>  <Plug>(vimshell_history_complete_whole)
imap <buffer> <C-r>c  <Plug>(vimshell_history_complete_insert)
" Command completion.
imap <buffer> <TAB>  <Plug>(vimshell_command_complete)
" Move to Beginning of command.
imap <buffer> <C-a> <Plug>(vimshell_move_head)
" Delete all entered characters in the current line
imap <buffer> <C-u> <Plug>(vimshell_delete_line)
" Push current line to stack.
imap <buffer> <C-z> <Plug>(vimshell_push_current_line)
" Insert last word.
imap <buffer> <C-]> <Plug>(vimshell_insert_last_word)
" Run help.
imap <buffer> <C-r>h <Plug>(vimshell_run_help)
" Clear.
imap <buffer> <C-l> <Plug>(vimshell_clear)
"}}}
