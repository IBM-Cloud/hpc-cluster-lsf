locals {
  image_region_map = {
    "hpcc-lsf10-scale5201-rhel88-5-0" = {
      "eu-gb"     = "r018-e16eb40f-d0ae-4162-ba30-036a4b6d02f3"
      "eu-de"     = "r010-497895dc-f719-48ea-a4f2-c84a87cd6f88"
      "us-east"   = "r014-ac280a4b-b587-4a3f-a24d-2eecc73933ca"
      "us-south"  = "r006-278e7f41-6850-450d-9fb6-e3499d644b92"
      "jp-tok"    = "r022-5765e0b0-233c-43ff-bf8b-a8e492f2fbe8"
      "jp-osa"    = "r034-9d5dec3d-f218-4987-9091-c4888a31c8a1"
      "au-syd"    = "r026-7a18f2dd-95ab-4ca6-b87c-d1d2732d41e7"
      "br-sao"    = "r042-d402bc54-fd47-48bf-997b-86fc748eabca"
      "ca-tor"    = "r038-8f2c9746-d7f9-4ad0-bbcb-e5962f6751af"
    },
    "hpc-lsf10-rhel88-worker-v1" = {
      "eu-gb"     = "r018-c2263cbc-2601-409c-a632-9dde770712e8"
      "eu-de"     = "r010-b65e3d42-917f-4b4d-a060-6c56a3592342"
      "us-east"   = "r014-feffc667-07a9-4493-a43d-48369a26b4bf"
      "us-south"  = "r006-ba870bcd-f20f-4ad5-8972-648c80d471bd"
      "jp-tok"    = "r022-67a2bfef-76d7-47d6-8467-f4943e361b11"
      "jp-osa"    = "r034-d1d493f4-ffaf-4cd7-b8d8-f0249dc1bbb3"
      "au-syd"    = "r026-f9d5835d-7a1d-4f49-9074-f3953764c553"
      "br-sao"    = "r042-63151956-7437-412d-8c8d-df460d96883e"
      "ca-tor"    = "r038-66b71770-7197-43af-a43d-fc25bdfe015b"
    }
  }
}
