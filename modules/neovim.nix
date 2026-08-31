{ pkgs, ... }:

let
  treesitter = pkgs.vimPlugins.nvim-treesitter.withPlugins (
    parsers: with parsers; [
      bash
      c
      cpp
      javascript
      lua
      nix
      python
      rust
      tsx
      typescript
    ]
  );
in

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;

    # Language servers are visible inside Neovim without being added to the
    # user's general shell environment. Their runtimes are part of the Nix
    # closure, so Mason and the FNM PATH workaround are unnecessary.
    extraPackages = with pkgs; [
      bash-language-server
      clang-tools
      lua-language-server
      pyright
      rust-analyzer
      typescript-language-server
    ];

    initLua = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      local opt = vim.opt

      opt.number = true
      opt.relativenumber = true
      opt.expandtab = true
      opt.shiftwidth = 2
      opt.softtabstop = 2
      opt.tabstop = 2
      opt.smartindent = true
      opt.termguicolors = true
      opt.background = "light"
      opt.signcolumn = "yes"
      opt.splitbelow = true
      opt.splitright = true
      opt.ignorecase = true
      opt.smartcase = true
      opt.updatetime = 250

      local map = vim.keymap.set

      map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
      map("n", "<leader>fb", ":buffers<cr>:buffer ", { desc = "Switch buffer" })
      map("n", "<leader>fh", ":help ", { desc = "Open help" })

      map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
      map("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation" })
      map("n", "gr", vim.lsp.buf.references, { desc = "Find references" })
      map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
      map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
      map("n", "]d", function()
        vim.diagnostic.jump({ count = 1, float = true })
      end, { desc = "Next diagnostic" })
      map("n", "[d", function()
        vim.diagnostic.jump({ count = -1, float = true })
      end, { desc = "Previous diagnostic" })
    '';

    # Nix installs plugins and their native dependencies into an immutable
    # packpath. Plugin updates therefore follow flake.lock rather than a
    # second, mutable plugin manager and lock file.
    plugins = [
      {
        plugin = pkgs.vimPlugins.neovim-ayu;
        type = "lua";
        config = ''
          vim.o.background = "light"
          require("ayu").setup({})
          vim.cmd.colorscheme("ayu-light")
        '';
      }

      {
        plugin = pkgs.vimPlugins.fff-nvim;
        type = "lua";
        config = ''
          require("fff").setup({})

          local map = vim.keymap.set
          map("n", "<leader>ff", function()
            require("fff").find_files()
          end, { desc = "Find files" })
          map("n", "<leader>fg", function()
            require("fff").live_grep()
          end, { desc = "Live grep" })
          map({ "n", "x" }, "<leader>fw", function()
            require("fff").live_grep_under_cursor()
          end, { desc = "Search word or selection" })
        '';
      }

      {
        plugin = treesitter;
        type = "lua";
        config = ''
          vim.api.nvim_create_autocmd("FileType", {
            pattern = {
              "c",
              "cpp",
              "javascript",
              "lua",
              "nix",
              "python",
              "rust",
              "sh",
              "typescript",
              "typescriptreact",
            },
            callback = function(args)
              pcall(vim.treesitter.start, args.buf)
            end,
          })
        '';
      }

      {
        plugin = pkgs.vimPlugins.blink-cmp;
        type = "lua";
        config = ''
          require("blink.cmp").setup({
            keymap = { preset = "default" },
            completion = {
              documentation = {
                auto_show = true,
                auto_show_delay_ms = 300,
              },
            },
            fuzzy = { implementation = "lua" },
          })
        '';
      }

      {
        plugin = pkgs.vimPlugins.nvim-lspconfig;
        type = "lua";
        config = ''
          local capabilities = require("blink.cmp").get_lsp_capabilities()
          local servers = {
            bashls = {},
            clangd = {},
            lua_ls = {
              settings = {
                Lua = {
                  diagnostics = { globals = { "vim" } },
                  workspace = { library = vim.api.nvim_get_runtime_file("", true) },
                },
              },
            },
            ts_ls = {},
            pyright = {},
            rust_analyzer = {},
          }

          for name, config in pairs(servers) do
            config.capabilities = capabilities
            vim.lsp.config(name, config)
            vim.lsp.enable(name)
          end
        '';
      }

      {
        plugin = pkgs.vimPlugins.gitsigns-nvim;
        type = "lua";
        config = ''
          require("gitsigns").setup({})
        '';
      }
    ];
  };
}
