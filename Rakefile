VIMSHELL_TARGETS = %w[
  autoload/proc.vim
  autoload/vimshell
  autoload/interactive.vim
  autoload/vimshell.vim
  ftplugin/vimshell.vim
  plugin/interactive.vim
  plugin/vimshell.vim
  syntax/vimshell.vim
]

task :install do
  VIMSHELL_TARGETS.each do |f|
    FileUtils.cp_r "#{pwd}/#{f}", "#{$HOME}/.vim/#{f}"
  end
end

task :uninstall do
  VIMSHELL_TARGETS.each do |f|
    FileUtils.rm_r "#{$HOME}/.vim/#{f}"
  end
end

task :upgrade do
  warn "do `git pull`"
end

task :install_for_developpers do
  VIMSHELL_TARGETS.each do |f|
    sh "ln -s #{pwd}/#{f} ~/.vim/#{f}"
  end
end
