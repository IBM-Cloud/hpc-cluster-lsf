locals {
        image_region_map = {
          "hpcc-lsf10-scale5151-rhel84-2-1" = {
            "us-south" = "r006-81fd1256-bd98-4dc6-9a27-f43ad1db685f"
            "us-east"  = "r014-bd78eb0f-bedc-432d-ba89-16ffb16ba1e6"
            "au-syd"   = "r026-389d641d-fea8-4b86-8701-2894a09f315f"
            "jp-osa"   = "r034-a18449a3-979b-41a0-9ebd-2831ccbbaaef"
            "jp-tok"   = "r022-160e642c-2b9f-480f-bc04-2a06f9f200cb"
            "eu-de"    = "r010-ee38025e-28ff-443f-b935-0afc84d3ea5e"
            "eu-gb"    = "r018-0567f781-b141-4ee8-a767-af84bcce13b4"
            "ca-tor"   = "r038-abbbaf63-6b82-487f-b96c-7ae06430265d"
            "br-sao"   = "r042-aad163df-3049-4b6a-b5b1-735ff6ffec92"
          }
        }
}