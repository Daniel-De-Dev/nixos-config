local hostname = os.getenv('NIXOS_HOSTNAME') or vim.uv.os_gethostname()

---@type vim.lsp.Config
return {
  cmd = { 'nixd' },
  filetypes = { 'nix' },
  root_markers = { 'flake.nix', '.git' },
  settings = {
    nixd = {
      nixpkgs = {
        expr = 'import (builtins.getFlake ("git+file://" + toString ./.)).inputs.nixpkgs { }',
      },
      options = {
        nixos = {
          expr = string.format(
            '(builtins.getFlake ("git+file://" + toString ./.)).nixosConfigurations."%s".options',
            hostname
          ),
        },
        flake_inputs = {
          expr = '(builtins.getFlake ("git+file://" + toString ./.)).inputs',
        },
      },
    },
  },
}
