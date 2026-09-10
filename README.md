# Project Gutenberg Bulk Downloader

Repositório para criar e manter um mirror local do acervo do Project Gutenberg usando `rsync`, conforme o método recomendado para download em massa.

> Importante: o acervo completo é grande demais para ser armazenado diretamente em um repositório GitHub comum. Este repositório controla o download e direciona os livros para um disco, servidor ou volume externo configurado por você.

## Uso rápido

### Linux / macOS

```bash
chmod +x download_gutenberg_all.sh
./download_gutenberg_all.sh /caminho/ProjectGutenberg full
```

### Windows

Recomendado: WSL/Ubuntu com `rsync` instalado.

```powershell
.\download_gutenberg_all.ps1 -Destination "D:\ProjectGutenberg" -Mode full
```

## Modos

- `full`: coleção principal + coleção gerada.
- `generated`: EPUB/Kindle/HTML gerado + metadados.
- `main`: coleção principal curada.

## Atualização incremental

Execute novamente o mesmo comando. O `rsync` transfere somente os arquivos novos ou alterados.

## Destino dos livros

Por padrão, os arquivos ficam fora do Git, em uma pasta escolhida no primeiro argumento. Isso evita ultrapassar os limites de tamanho do GitHub e mantém o repositório leve.

Exemplo:

```bash
./download_gutenberg_all.sh /mnt/storage/project-gutenberg full
```

Estrutura esperada:

```text
/mnt/storage/project-gutenberg/
├── main/
└── generated/
```

## Requisitos

- `rsync`
- conexão estável
- espaço em disco suficiente para o mirror completo

## Fontes

- Project Gutenberg Robot Access
- Project Gutenberg Mirroring How-To
