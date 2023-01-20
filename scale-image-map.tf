# This mapping file has entries for scale storage node images
locals {
  scale_image_region_map = {
    "hpcc-scale5131-rhel84" = {
      "eu-de"   = "r010-c14fa853-1169-444e-909e-1a1addf5946b"
      "us-east" = "r014-61b34bff-1c94-4f4b-82ec-10d73282b58e"
      "us-south"= "r006-d07da9bc-4f5a-4148-8e02-0d50f17622c5"
      "jp-tok"  = "r022-025b7f85-4db8-4d12-ac33-559224fa7590"
      "eu-gb"   = "r018-26688b36-3683-471b-b975-6ec5de26f8ba"
      "jp-osa"  = "r034-a024798f-10df-4ee6-8338-6b79204b9b13"
      "ca-tor"  = "r038-6890ead3-4bac-4a77-bbea-bd123aa15262"
      "au-syd"  = "r026-8d58f05a-c71d-4b7e-9be0-ba6638ca8bce"
      "br-sao"  = "r042-dcbd4acd-9e42-45b3-9b1d-16f82803b222"
    }
  }
}