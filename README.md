code-slices.vim
===============

The code-slices plugin about collecting lines or blocks of code and. It was
started as a personal project to speed up the learning curve of new frameworks
or languages by reusing previously typed/copypasted fragmets code directly
from vim. It's different from snippets plugins like ultisnips, snipmate and
xptemplate because It show you the complete block of code in a special window
with syntax higlighting and beacause it's not in its purposes to do inplace
transformations like snippets plugins do. Its main purpose is to be a tool to
collect code slices in a quick, easy and even fun way so, it can help you to
learn new tools (by reducing the time you have too search in documentation)
and to collect and reuse boilerplate code so you don't have to type or
copypaste It

### Installing code-slices

Because code-slices is pathogen compatible you can just clone the repo in your
bundle plugin:


Similar steps should be performed to use it with Vundle

### Before start

The default configuration of code-slices is to search for the slices's
directory in your .vim directory in the structure:

        $HOME
        |~.vim
        | |-slices
        | `-{filetype}.slices

You can change the default slices directory by using the global variable
g:slices\_preferred\_path for example I'm storing the slices in the path
$HOME/code-slices/slices/ with the configuration:

        let g:slices_preferred_path=expand('$HOME') . '/code-slices'

Remember that the plugin automatically adds 'slices' to the path

### Using the plugin

The first interaction you should have with the plugin should be to create a
Slice by using a visual selection


### Writing slices

