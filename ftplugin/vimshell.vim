" Key mappings.
" 
" Execute command.
nmap <buffer><silent> <CR> <Plug>(vimshell_enter)
imap <buffer><silent> <CR> <ESC><CR>
" Hide vimshell.
nnoremap <buffer><silent> q :<C-u>hide<CR>
" History completion.
inoremap <buffer> <C-j> <C-x><C-o><C-p>
" Move to Beginning of command.
imap <buffer><silent> <C-a> <ESC>:call search(g:VimShell_Prompt, 'be', line('.'))<CR>a
" Command completion.
imap <buffer> <C-p> <Plug>(vimshell_insert_command_completion)
" Push current line to stack.
imap <buffer> <C-z> <Plug>(vimshell_push_current_line)
" Insert last word.
imap <buffer> <C-]> <Plug>(vimshell_insert_last_word)
" Run help.
imap <buffer> <C-r> <Plug>(vimshell_run_help)
" Move to previous prompt.
nmap <buffer> <C-p> <Plug>(vimshell_previous_prompt)
" Move to next prompt.
nmap <buffer> <C-n> <Plug>(vimshell_next_prompt)
" Remove this output.
nmap <buffer> <C-d> <Plug>(vimshell_delete_previous_prompt)

" Filename completion.
inoremap <buffer><expr><TAB>  pumvisible() ? "\<C-n>" : exists(':NeoComplCacheDisable') && exists('*neocomplcache#manual_filename_complete') ? 
            \ neocomplcache#manual_filename_complete() : "\<C-x>\<C-f>"

