# This mapping file has entries for scale storage node images
locals {
  scale_image_region_map = {
    "hpcc-scale5131-rhel84-jun0122-v1" = {
      "eu-de"   = "r010-f26116c5-66b5-41be-b081-bafc9af4d0f9"
      "us-east" = "r014-cd25a87d-96c7-4b51-ab22-63cccb65985b"
      "us-south"= "r006-e388ff31-3637-4613-8872-80033a925db6"
      "jp-tok"  = "r022-0aa7a74f-8922-44cf-8a74-8d4c39b80143"
      "eu-gb"   = "r018-d544e3c3-bda5-44c0-8cc3-ba8306cc69d2"
      "jp-osa"  = "r034-8cafc8d5-11a7-4d63-9f05-c3f725214288"
      "ca-tor"  = "r038-8b881d90-1fe6-4d11-a4f4-3770305589fb"
      "au-syd"  = "r026-35832f39-df05-4b6c-b213-d8cb5a2cfcb9"
      "br-sao"  = "r042-80543a2f-9ecb-4942-b637-40b7413128c2"
    }
  }
}