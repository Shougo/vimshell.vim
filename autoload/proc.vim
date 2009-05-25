" 2006-08-19

scriptencoding utf-8

function! proc#import()
  call s:lib.load()
  return s:lib
endfunction

augroup ProcPlug
  autocmd!
  autocmd VimLeave * call s:lib.unload()
augroup END

let s:lib = {}
let s:lib.api = {}
let s:lib.lasterr = []
let s:lib.read_timeout = 100
let s:lib.write_timeout = 100

function! s:lib.load()
  return self.api.load()
endfunction

function! s:lib.unload()
  call self.api.unload()
endfunction

function! s:lib.open(path, flags, ...)
  let mode = get(a:000, 0, 0)
  let fd = self.api.vp_file_open(a:path, a:flags, mode)
  return self.fdopen(fd, self.api.vp_file_close, self.api.vp_file_read, self.api.vp_file_write)
endfunction

function! s:lib.close()
  call self.f_close(self.fd)
  let self.fd = -1
endfunction

function! s:lib.read(...)
  let nr = get(a:000, 0, -1)
  let timeout = get(a:000, 1, self.read_timeout)
  let [hd, eof] = self.f_read(self.fd, nr, timeout)
  let self.eof = eof
  return self.hd2str(hd)
endfunction

function! s:lib.write(str, ...)
  let timeout = get(a:000, 0, self.write_timeout)
  let hd = self.str2hd(a:str)
  return self.f_write(self.fd, hd, timeout)
endfunction

function! s:lib.popen2(args)
  let [pid, fd_stdin, fd_stdout] = self.api.vp_pipe_open(2, a:args)
  let proc = {}
  let proc.pid = pid
  let proc.stdin = self.fdopen(fd_stdin, self.api.vp_pipe_close, self.api.vp_pipe_read, self.api.vp_pipe_write)
  let proc.stdout = self.fdopen(fd_stdout, self.api.vp_pipe_close, self.api.vp_pipe_read, self.api.vp_pipe_write)
  return proc
endfunction

function! s:lib.popen3(args)
  let [pid, fd_stdin, fd_stdout, fd_stderr] = self.api.vp_pipe_open(3, a:args)
  let proc = {}
  let proc.pid = pid
  let proc.stdin = self.fdopen(fd_stdin, self.api.vp_pipe_close, self.api.vp_pipe_read, self.api.vp_pipe_write)
  let proc.stdout = self.fdopen(fd_stdout, self.api.vp_pipe_close, self.api.vp_pipe_read, self.api.vp_pipe_write)
  let proc.stderr = self.fdopen(fd_stderr, self.api.vp_pipe_close, self.api.vp_pipe_read, self.api.vp_pipe_write)
  return proc
endfunction

function! s:lib.socket_open(host, port)
  let fd = self.api.vp_socket_open(a:host, a:port)
  return self.fdopen(fd, self.api.vp_socket_close, self.api.vp_socket_read, self.api.vp_socket_write)
endfunction

function! s:lib.fdopen(fd, f_close, f_read, f_write)
  let file = copy(self)
  call extend(file, self.api)
  let file.fd = a:fd
  let file.eof = 0
  let file.f_close = a:f_close
  let file.f_read = a:f_read
  let file.f_write = a:f_write
  return file
endfunction

function! s:lib.ptyopen(args)
  let [pid, fd, ttyname] = self.api.vp_pty_open(&winwidth, &winheight, a:args)

  let proc =  self.fdopen(fd, self.api.vp_pty_close, self.api.vp_pty_read, self.api.vp_pty_write)
  let proc.pid = pid
  let proc.ttyname = ttyname
  return proc
endfunction



"-----------------------------------------------------------
" UTILS

function! s:lib.str2hd(str)
  return join(map(range(len(a:str)), 'printf("%02X", char2nr(a:str[v:val]))'), "")
endfunction

function! s:lib.hd2str(hd)
  " Since Vim can not handle \x00 byte, remove it.
  " do not use nr2char()
  " nr2char(255) => "\xc3\xbf" (utf8)
  return join(map(split(a:hd, '..\zs'), 'v:val == "00" ? "" : eval(''"\x'' . v:val . ''"'')'), "")
endfunction

function! s:lib.str2list(str)
  return map(range(len(a:str)), 'char2nr(a:str[v:val])')
endfunction

function! s:lib.list2str(lis)
  return self.hd2str(self.list2hd(a:lis))
endfunction

function! s:lib.hd2list(hd)
  return map(split(a:hd, '..\zs'), 'str2nr(v:val, 16)')
endfunction

function! s:lib.list2hd(lis)
  return join(map(a:lis, 'printf("%02X", v:val)'), "")
endfunction



"-----------------------------------------------------------
" LOW LEVEL API
let s:lib.api.handle = ""

if has("win32")
  let s:lib.api.dll = expand("<sfile>:p:h") . "/proc.dll"
else
  let s:lib.api.dll = expand("<sfile>:p:h") . "/proc.so"
endif
if has('iconv')
  " dll path should be encoded with default encoding.  Vim does not convert
  " it from &enc to default encoding.
  let s:lib.api.dll = iconv(s:lib.api.dll, &encoding, "default")
endif

function! s:lib.api.libcall(func, args)
  " End Of Value
  let EOV = "\xFF"
  let args = empty(a:args) ? "" : (join(reverse(copy(a:args)), EOV) . EOV)
  let stack_buf = libcall(self.dll, a:func, args)
  " why this does not work?
  " let res = split(stack_buf, EOV, 1)
  let res = split(stack_buf, '[\xFF]', 1)
  if !empty(res) && res[-1] != ""
    let self.lasterr = res
    let msg = string(res)
    if has("iconv") && has("win32")
      " kernel error message is encoded with system codepage.
      " XXX: other normal error message may be encoded with &enc.
      let msg = iconv(msg, "default", &enc)
    endif
    throw printf("proc: %s: %s", a:func, msg)
  endif
  return res[:-2]
endfunction

function! s:lib.api.load()
  if self.handle == ""
    let handle = self.vp_dlopen(self.dll)
    let self.handle = handle
  endif
  return self.handle
endfunction

function! s:lib.api.unload()
  if self.handle != ""
    call self.vp_dlclose(self.handle)
    let self.handle = ""
  endif
endfunction

function! s:lib.api.vp_dlopen(path)
  let [handle] = self.libcall("vp_dlopen", [a:path])
  return handle
endfunction

function! s:lib.api.vp_dlclose(handle)
  call self.libcall("vp_dlclose", [a:handle])
endfunction

function! s:lib.api.vp_file_open(path, flags, mode)
  let [fd] = self.libcall("vp_file_open", [a:path, a:flags, a:mode])
  return fd
endfunction

function! s:lib.api.vp_file_close(fd)
  call self.libcall("vp_file_close", [a:fd])
endfunction

function! s:lib.api.vp_file_read(fd, nr, timeout)
  let [hd, eof] = self.libcall("vp_file_read", [a:fd, a:nr, a:timeout])
  return [hd, eof]
endfunction

function! s:lib.api.vp_file_write(fd, hd, timeout)
  let [nleft] = self.libcall("vp_file_write", [a:fd, a:hd, a:timeout])
  return nleft
endfunction

function! s:lib.api.vp_pipe_open(npipe, argv)
  if has("win32")
    let cmdline = ""
    for arg in a:argv
      let cmdline .= '"' . substitute(arg, '"', '""', 'g') . '" '
    endfor
    let [pid; fdlist] = self.libcall("vp_pipe_open", [a:npipe, cmdline])
  else
    let [pid; fdlist] = self.libcall("vp_pipe_open",
          \ [a:npipe, len(a:argv)] + a:argv)
  endif
  return [pid] + fdlist
endfunction

function! s:lib.api.vp_pipe_close(fd)
  call self.libcall("vp_pipe_close", [a:fd])
endfunction

function! s:lib.api.vp_pipe_read(fd, nr, timeout)
  let [hd, eof] = self.libcall("vp_pipe_read", [a:fd, a:nr, a:timeout])
  return [hd, eof]
endfunction

function! s:lib.api.vp_pipe_write(fd, hd, timeout)
  let [nleft] = self.libcall("vp_pipe_write", [a:fd, a:hd, a:timeout])
  return nleft
endfunction

function! s:lib.api.vp_pty_open(width, height, argv)
  let [pid, fd, ttyname] = self.libcall("vp_pty_open",
        \ [a:width, a:height, len(a:argv)] + a:argv)
  return [pid, fd, ttyname]
endfunction

function! s:lib.api.vp_pty_close(fd)
  call self.libcall("vp_pty_close", [a:fd])
endfunction

function! s:lib.api.vp_pty_read(fd, nr, timeout)
  let [hd, eof] = self.libcall("vp_pty_read", [a:fd, a:nr, a:timeout])
  return [hd, eof]
endfunction

function! s:lib.api.vp_pty_write(fd, hd, timeout)
  let [nleft] = self.libcall("vp_pty_write", [a:fd, a:hd, a:timeout])
  return nleft
endfunction

function! s:lib.api.vp_pty_get_winsize(fd)
  let [width, height] = self.libcall("vp_pty_get_winsize", [a:fd])
  return [width, height]
endfunction

function! s:lib.api.vp_pty_set_winsize(fd, width, height)
  call self.libcall("vp_pty_set_winsize", [a:fd, a:width, a:height])
endfunction

function! s:lib.api.vp_kill(pid, sig)
  call self.libcall("vp_kill", [a:pid, a:sig])
endfunction

function! s:lib.api.vp_waitpid(pid)
  let [cond, status] = self.libcall("vp_waitpid", [a:pid])
  return [cond, status]
endfunction

function! s:lib.api.vp_socket_open(host, port)
  let [socket] = self.libcall("vp_socket_open", [a:host, a:port])
  return socket
endfunction

function! s:lib.api.vp_socket_close(socket)
  call self.libcall("vp_socket_close", [a:socket])
endfunction

function! s:lib.api.vp_socket_read(socket, nr, timeout)
  let [hd, eof] = self.libcall("vp_socket_read", [a:socket, a:nr, a:timeout])
  return [hd, eof]
endfunction

function! s:lib.api.vp_socket_write(socket, hd, timeout)
  let [n] = self.libcall("vp_socket_write", [a:socket, a:hd, a:timeout])
  return n
endfunction

