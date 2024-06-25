# This mapping file has entries for scale storage node images.
locals {
  scale_image_region_map = {
    "hpcc-scale5193-rhel88" = {
      "eu-gb" = "r018-d9767d47-be92-4854-8f8b-ac3c9c568f6f"
      "eu-de" = "r010-5536f489-989b-45cd-ad09-3d950d71fdfb"
      "us-east" = "r014-0af1e16f-10ec-4cb5-8327-8a98b50a4a20"
      "us-south" = "r006-d9abf22e-706e-490d-aac1-3574e96d77e6"
      "jp-tok" = "r022-d3566ef3-39b1-4174-8724-e421956cba9c"
      "jp-osa" = "r034-25df9173-e947-4a43-81dc-0cf393671e4a"
      "au-syd" = "r026-f1e8a393-b4c4-48db-bd85-ebe809a57ab3"
      "br-sao" = "r042-f5d9533e-04d8-442f-a1b0-ec5c3454b07c"
      "ca-tor" = "r038-9a14f386-b4a9-4da2-ab00-d0f1c8a39d55"
    }
  }
}