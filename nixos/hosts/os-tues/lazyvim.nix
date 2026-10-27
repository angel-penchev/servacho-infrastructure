# LazyVim as everyone's nvim on os-tues (docs/os-tues.md).
#
# Neovim reads $XDG_CONFIG_DIRS/nvim/init.lua when a user has no
# ~/.config/nvim/init.lua, so the init.lua below is every account's config
# until its owner writes one of their own. Normally lazy.nvim clones LazyVim's
# plugins into each home, nvim-treesitter compiles its parsers there and Mason
# downloads language servers; here Nix provides all of them, so nvim starts
# the same for every account, offline and without a copy per home.
#
# Students change it from ~/.config/nvim/lua/: config/options.lua,
# keymaps.lua and autocmds.lua as in LazyVim's starter, and plugins/*.lua for
# plugin specs. lazy.nvim clones a plugin that isn't here into their home.
{ lib, pkgs, ... }:
let
  inherit (pkgs) vimPlugins;

  # What LazyVim's spec and its clangd extra ask for, by lazy.nvim's name for
  # each plugin: the repository's. Mason and mason-lspconfig are left out
  # (disabled below). After a nixpkgs update, LazyVim may ask for one that
  # isn't here; lazy.nvim then clones it into every home, which the flake's
  # checks.os-tues-lazyvim catches.
  plugins = {
    LazyVim = vimPlugins.LazyVim;
    "blink.cmp" = vimPlugins.blink-cmp;
    "bufferline.nvim" = vimPlugins.bufferline-nvim;
    catppuccin = vimPlugins.catppuccin-nvim;
    "clangd_extensions.nvim" = vimPlugins.clangd_extensions-nvim;
    "conform.nvim" = vimPlugins.conform-nvim;
    "flash.nvim" = vimPlugins.flash-nvim;
    friendly-snippets = vimPlugins.friendly-snippets;
    "gitsigns.nvim" = vimPlugins.gitsigns-nvim;
    "grug-far.nvim" = vimPlugins.grug-far-nvim;
    "lazy.nvim" = vimPlugins.lazy-nvim;
    "lazydev.nvim" = vimPlugins.lazydev-nvim;
    "lualine.nvim" = vimPlugins.lualine-nvim;
    "mini.ai" = vimPlugins.mini-ai;
    "mini.icons" = vimPlugins.mini-icons;
    "mini.pairs" = vimPlugins.mini-pairs;
    "noice.nvim" = vimPlugins.noice-nvim;
    "nui.nvim" = vimPlugins.nui-nvim;
    nvim-lint = vimPlugins.nvim-lint;
    nvim-lspconfig = vimPlugins.nvim-lspconfig;
    nvim-treesitter = vimPlugins.nvim-treesitter;
    nvim-treesitter-textobjects = vimPlugins.nvim-treesitter-textobjects;
    nvim-ts-autotag = vimPlugins.nvim-ts-autotag;
    "persistence.nvim" = vimPlugins.persistence-nvim;
    "plenary.nvim" = vimPlugins.plenary-nvim;
    "snacks.nvim" = vimPlugins.snacks-nvim;
    "todo-comments.nvim" = vimPlugins.todo-comments-nvim;
    "tokyonight.nvim" = vimPlugins.tokyonight-nvim;
    "trouble.nvim" = vimPlugins.trouble-nvim;
    "ts-comments.nvim" = vimPlugins.ts-comments-nvim;
    "which-key.nvim" = vimPlugins.which-key-nvim;
  };
  pluginDir = pkgs.linkFarm "lazyvim-plugins" plugins;

  # Treesitter parsers and their queries, laid out as nvim-treesitter's
  # install_dir (parser/<lang>.so, queries/<lang>/): on its main branch, which
  # LazyVim uses, a language counts as installed only if it is there. LazyVim's
  # own list, the clangd extra's cpp, and what the class writes besides.
  languages = [
    "bash"
    "c"
    "diff"
    "html"
    "javascript"
    "jsdoc"
    "json"
    "lua"
    "luadoc"
    "luap"
    "markdown"
    "markdown_inline"
    "printf"
    "python"
    "query"
    "regex"
    "toml"
    "tsx"
    "typescript"
    "vim"
    "vimdoc"
    "xml"
    "yaml"
    "cpp"
    "asm"
    "nasm"
    "make"
    "gitcommit"
    "git_rebase"
    "gitignore"
  ];
  withDependencies = p: [ p ] ++ lib.concatMap withDependencies (p.dependencies or [ ]);
  treesitter = pkgs.symlinkJoin {
    name = "lazyvim-treesitter";
    paths = lib.unique (
      lib.concatMap withDependencies
        (vimPlugins.nvim-treesitter.withPlugins (p: map (lang: p.${lang}) languages)).dependencies
    );
  };

  init = pkgs.writeText "lazyvim-init.lua" ''
    -- LazyVim for every account without a ~/.config/nvim/init.lua of its own.
    -- Written by servacho-infrastructure's nixos/hosts/os-tues/lazyvim.nix.
    vim.opt.rtp:prepend("${vimPlugins.lazy-nvim}")

    -- What LazyVim and lazy.nvim write, they write to ~/.local/state/nvim,
    -- so that ~/.config/nvim stays the user's.
    local state = vim.fn.stdpath("state")
    vim.g.lazyvim_json = state .. "/lazyvim.json"

    local spec = {
      { "LazyVim/LazyVim", import = "lazyvim.plugins" },
      { import = "lazyvim.plugins.extras.lang.clangd" },
      -- Nix provides clangd and lua-language-server; Mason would download
      -- them into every home.
      { "mason-org/mason.nvim", enabled = false },
      { "mason-org/mason-lspconfig.nvim", enabled = false },
      -- The parsers are Nix's and read-only: nothing to install.
      {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
          opts.install_dir = "${treesitter}"
          opts.ensure_installed = {}
        end,
      },
    }
    if vim.uv.fs_stat(vim.fn.stdpath("config") .. "/lua/plugins") then
      spec[#spec + 1] = { import = "plugins" }
    end

    require("lazy").setup({
      spec = spec,
      -- Every plugin from Nix's set when it is there; one that isn't is
      -- cloned into ~/.local/share/nvim/lazy.
      dev = { path = "${pluginDir}", patterns = { "" }, fallback = true },
      lockfile = state .. "/lazy-lock.json",
      install = { colorscheme = { "tokyonight", "habamax" } },
      checker = { enabled = false },
      change_detection = { notify = false },
      rocks = { enabled = false },
      performance = {
        rtp = {
          disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
        },
      },
    })
  '';

  # What LazyVim calls out to: its pickers search with rg and fd, <leader>gg
  # opens lazygit, and the language servers for C and Lua.
  tools = with pkgs; [
    git
    ripgrep
    fd
    lazygit
    clang-tools
    lua-language-server
  ];
in
{
  environment.etc."xdg/nvim/init.lua".source = init;

  environment.systemPackages = tools;

  # The flake's checks.os-tues-lazyvim.
  system.build.lazyvimCheck =
    pkgs.runCommand "os-tues-lazyvim-check" { nativeBuildInputs = [ pkgs.neovim ] ++ tools; }
      ''
        export HOME=$TMPDIR/home XDG_CONFIG_DIRS=$TMPDIR/xdg
        mkdir -p $HOME $XDG_CONFIG_DIRS/nvim
        ln -s ${init} $XDG_CONFIG_DIRS/nvim/init.lua
        printf '#include <stdio.h>\n\nint main(void) {\n  puts("hi");\n}\n' >hello.c
        nvim --headless hello.c -c 'luafile ${./lazyvim-check.lua}'
        touch $out
      '';
}
