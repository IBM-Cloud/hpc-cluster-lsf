locals {
        image_region_map = {
          "hpcc-lsf10-cent77-jul2221-v6" = {
            "us-south" = "r006-68478a2e-4abc-4bfb-9e4f-a6fb3b9b235f"
            "us-east" = "r014-4ccae2ea-b286-451b-9667-7e36d759aa5b"
            "au-syd" =  "r026-2af74cdf-5331-4ca8-9c13-ef4421197260"
            "jp-osa" = "r034-91e72596-93db-4ba2-baa9-743cb4378405"
            "jp-tok" = "r022-375ada4e-3afd-41df-a189-0a53aaa16767"
            "eu-de" = "r010-f42f2d27-6aea-442b-ab8b-e7f4c6bd986f"
            "eu-gb" = "r018-fc3cde1a-1a27-4bd7-92f9-6861a6bb1f70"
            "ca-tor" = "r038-5dfd9553-2862-4d7f-9f04-68e9d8831905"
            "br-sao" = "r042-e0ae845a-1a38-4689-a6a7-3ab7c755053d"
          }

          "hpcc-lsf10-rhel77-jul2221-v6" = {
            "us-south" = "r006-1d68600f-a172-4c03-b2f7-f9b9c4154748"
            "us-east" = "r014-2811253a-959e-44db-88d8-4355c339264a"
            "au-syd" =  "r026-cced3073-d61c-47bc-bfe9-86a1eab91699"
            "jp-osa" = "r034-cd4676d3-f469-4897-810f-f737efe800ff"
            "jp-tok" = "r022-8bf9765b-3bde-408c-b819-40a00404345e"
            "eu-de" = "r010-c9d55371-3cf8-4097-8682-432a1897ca1d"
            "eu-gb" = "r018-bd64329d-b967-431c-845c-40a9596eff7c"
            "ca-tor" = "r038-2cb5b249-08b0-4025-9f49-27cdc8d45f55"
            "br-sao" = "r042-8ec2cb42-4d32-4a54-8ce0-70980c4a11c7"
          }

          "hpcc-lsf10-rhel77-jun0421-v5" = {
            "us-south" = "r006-0345002d-7d94-4104-a5d3-be60abd4a018"
            "us-east" = "r014-52be9682-a6f2-4da8-8b27-be28a2d9c42d"
            "au-syd" =  "r026-ddfcabea-7e7c-4c97-a27d-5657f39b61ff"
            "jp-osa" = "r034-1b692a05-ba5c-4c7e-88cb-c369421b9321"
            "jp-tok" = "r022-a0e68b10-eb0b-4c75-8607-4615e59129af"
            "eu-de" = "r010-07009d53-39cd-42af-9722-09fb00a3a6f5"
            "eu-gb" = "r018-508ecd59-abc6-43ae-9af7-bef25d2de912"
            "ca-tor" = "r038-b99ce407-206f-4dc0-baa8-340afe85219e"
            "br-sao" = "r042-9b5e67e7-e306-44e4-9897-f4aa96b07836"
          }

          "hpcc-lsf10-cent77-jun0421-v5" = {
            "us-south" = "r006-65a9e8e9-6b8f-4f67-b708-b5bfbe219101"
            "us-east" = "r014-6791e5cd-d5a9-4f57-8047-a56b0305f2b9"
            "au-syd" =  "r026-279b240a-5c07-4e00-bedb-ef6a77bfd232"
            "jp-osa" = "r034-d3a5eab7-8908-4216-a250-f3466eb4fc1b"
            "jp-tok" = "r022-31213a59-ebff-4dbe-af80-e3d360e3bc61"
            "eu-de" = "r010-c2541e7a-f2df-44ab-b2a1-8d6dee83da4f"
            "eu-gb" = "r018-3a4561aa-a37e-43f4-b68d-e9575af66d94"
            "ca-tor" = "r038-d83b89eb-dbdf-444c-80a5-a8434ad202ab"
            "br-sao" = "r042-f9c46fad-0022-4ca9-b716-096748affab7"
          }
          "hpcc-lsf10-scale5131-rhel84-060822-v1" = {
            "eu-de"   = "r010-12fc0cbb-a4c4-4fcc-a23a-f16aac05d4c9"
            "us-east" = "r014-c234f6c7-1ee5-4e53-a41a-95d12d002267"
            "us-south"= "r006-72c72135-e316-4859-bd04-59dfbfc49f7e"
            "jp-tok"  = "r022-21a19e42-db68-4ab1-a2b3-b08a30e0cd0f"
            "eu-gb"   = "r018-f79c488a-dddf-4a80-84db-c8e67707c5ab"
            "jp-osa"  = "r034-3bccbe09-02f5-4ae8-ad60-5b127dfabb26"
            "ca-tor"  = "r038-2fa9bef2-869e-41c8-ae67-18d2c4ed7f8f"
            "au-syd"  = "r026-2af8be22-3994-42db-838c-e2be6eefb0fc"
            "br-sao"  = "r042-4ba7845d-9ae7-4f4f-9c5b-dac25278bb10"
          }
        }
}
