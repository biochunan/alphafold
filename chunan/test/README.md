# Notes

Test scripts for AlphaFold docker image.

Use `./src/generate-msa.sh` to generate multiple sequence alignment (MSA) for a given sequence file (`input/7a3o_0P.fasta`).
Generated MSA will be saved in `./out/7a3o_0P` with the following files:

```shell
7a3o_0P
├── 7a3o_0P
│   ├── features.pkl
│   └── msas
│       ├── A
│       │   ├── bfd_uniref_hits.a3m
│       │   ├── mgnify_hits.sto
│       │   ├── pdb_hits.sto
│       │   ├── uniprot_hits.sto
│       │   └── uniref90_hits.sto
│       ├── B
│       │   ├── bfd_uniref_hits.a3m
│       │   ├── mgnify_hits.sto
│       │   ├── pdb_hits.sto
│       │   ├── uniprot_hits.sto
│       │   └── uniref90_hits.sto
│       ├── C
│       │   ├── bfd_uniref_hits.a3m
│       │   ├── mgnify_hits.sto
│       │   ├── pdb_hits.sto
│       │   ├── uniprot_hits.sto
│       │   └── uniref90_hits.sto
│       └── chain_id_map.json
├── 7a3o_0P.fasta
├── run_msa.log
└── time.log
```
