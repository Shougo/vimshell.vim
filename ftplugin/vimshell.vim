" Key mappings.
nmap <buffer><silent> <CR> <Plug>(vimshell_enter)
imap <buffer><silent> <CR> <ESC><CR>
nnoremap <buffer><silent> q :<C-u>hide<CR>
inoremap <buffer> <C-j> <C-x><C-o><C-p>
imap <buffer> <C-p> <C-o><Plug>(vimshell_insert_command_completion)
imap <buffer> <C-z> <C-o><Plug>(vimshell_push_current_line)
nmap <buffer> <C-p> <Plug>(vimshell_previous_prompt)
nmap <buffer> <C-n> <Plug>(vimshell_next_prompt)

" Filename completion.
inoremap <buffer><expr><TAB>  pumvisible() ? "\<C-n>" : "\<C-x>\<C-f>"
