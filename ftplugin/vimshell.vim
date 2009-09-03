" Key mappings.
" 

" Normal mode key-mappings.""{{{
" Execute command.
nmap <buffer> <CR> <Plug>(vimshell_enter)
" Hide vimshell.
nnoremap <buffer><silent> q :<C-u>hide<CR>
" Move to previous prompt.
nmap <buffer> <C-p> <Plug>(vimshell_previous_prompt)
" Move to next prompt.
nmap <buffer> <C-n> <Plug>(vimshell_next_prompt)
" Remove this output.
nmap <buffer> <C-d> <Plug>(vimshell_delete_previous_output)
" Paste this prompt.
nmap <buffer> <C-y> <Plug>(vimshell_paste_prompt)
"}}}

" Insert mode key-mappings."{{{
" Execute command.
imap <buffer> <CR> <ESC><Plug>(vimshell_enter)
" History completion.
inoremap <buffer><expr><C-j>  exists(':NeoComplCacheDisable') && exists('*neocomplcache#manual_omni_complete') ? 
            \ neocomplcache#manual_omni_complete() : "\<C-x>\<C-o>\<C-p>"
" Command completion.
"inoremap <buffer><expr><TAB>  pumvisible() ? "\<C-n>" : exists(':NeoComplCacheDisable') && exists('*neocomplcache#manual_filename_complete') ? 
"\ neocomplcache#manual_filename_complete() : "\<C-x>\<C-f>"
imap <buffer><expr><TAB> pumvisible() ? "\<C-n>" : "\<Plug>(vimshell_insert_command_completion)"
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
