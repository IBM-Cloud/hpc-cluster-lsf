locals {
  image_region_map = {
    "hpcaas-lsf10-rhel88-compute-v2" = {
      "us-east"  = "r014-ab4e0a87-4799-40b9-92c5-9efdb0d255df"
      "eu-de"    = "r010-1dc095d3-c358-4767-b3e1-77aa739498b5"
      "us-south" = "r006-4a9cc4ce-6d16-4726-b144-a90db827f592"
      "jp-osa"   = "r034-2a35a330-a6eb-4320-9f30-c8066c5870bf"
      "jp-tok"   = "r022-81b8996c-d434-48d7-8cc6-608389d35029"
      "ca-tor"   = "r038-40d41924-adde-4696-bf8e-5f0106311353"
      "br-sao"   = "r042-4ce19313-3f32-4ce1-8094-0a060d96d7e9"
      "eu-gb"    = "r018-779b453b-cc86-4d51-b9af-7b8be055f06a"
      "au-syd"   = "r026-38f6101e-0e10-4383-8030-3cd262bfc868"
    },
    "hpcaas-lsf10-ubuntu2204-compute-v1" = {
      "us-east"  = "r014-2874a5a3-9899-4d21-ba3b-863a65ac2a3c"
      "eu-de"    = "r010-6e221138-123a-488b-a2c1-072d057ec9f8"
      "us-south" = "r006-64c9971c-164b-4b0d-ac15-175b016760d2"
      "jp-osa"   = "r034-1bc75d86-48da-47d6-9ba2-b8a2f14648c7"
      "jp-tok"   = "r022-6f161bd6-5d5b-464f-a2ac-12284d9672a2"
      "ca-tor"   = "r038-efba5632-c6bb-462f-95e7-5cf55121b05c"
      "br-sao"   = "r042-eb24f32b-d2f8-4594-a0ef-aa713036283c"
      "eu-gb"    = "r018-b744184b-f997-4b80-abf5-46e10b99e231"
      "au-syd"   = "r026-4c54fbae-6c45-4d87-96b8-da6a421a5bba"
    },
    "hpcc-lsf10-scale5190-rhel88-3-0" = {
      "au-syd"   = "r026-2c97144b-46ca-4a46-bd58-2d97d9aa4e60"
      "br-sao"   = "r042-e1796337-8699-46da-a51c-822694836610"
      "ca-tor"   = "r038-709bb0c2-c5c7-4e93-9ed9-cdc672d706bf"
      "eu-de"    = "r010-f61bf731-e863-414a-b7dc-93b41de76643"
      "eu-gb"    = "r018-fe2655c5-74f3-475e-b192-95315ccd7381"
      "jp-osa"   = "r034-bd2073f7-ef95-4034-9b08-b7cea6a30070"
      "jp-tok"   = "r022-d812887d-0be6-445d-b563-3b2360dfa962"
      "us-east"  = "r014-a13f5472-c02e-4564-a7b1-b386819b0f95"
      "us-south" = "r006-15927eba-6656-4476-837d-41303d349c5d"
    },
    "hpcc-lsf10-scale5193-rhel88-4-0" = {
      "eu-gb" = "r018-556afbda-3204-4e7f-bcc8-83bd07a29c80"
      "eu-de" = "r010-13b69327-7287-486b-8063-1ca3b70f5b94"
      "us-east" = "r014-70ce8738-0779-4e2d-bf24-9ed1bdcd7b60"
      "us-south" = "r006-9d4db313-394d-402a-82ca-b016b4c2a631"
      "jp-tok" = "r022-6eb8b552-c696-4e3f-8226-bd2b9370bc6c"
      "jp-osa" = "r034-704e07cb-c2d6-4a2d-8250-b9602b09cc50"
      "au-syd" = "r026-22b2ba46-a7d3-440d-957c-65a25f860f91"
      "br-sao" = "r042-cb09d6af-685c-41e1-9435-61ce905600b7"
      "ca-tor" = "r038-14e1787f-0cc5-45ee-8b0a-08c09af0ad33"
    },
    "hpcc-lsf10-rhel88-compute-v3" = {
      "us-east" = "r014-e1446020-3ba5-40ee-a57e-af10cdf5b5dd"
      "ca-tor"  = "r038-8892ce30-2001-424b-b980-7073b16e6cc1"
      "jp-tok"  = "r022-77c14095-1bd5-449e-befd-06b895039512"
      "au-syd"  = "r026-411365ef-36d4-4ac0-b474-b16d14316fc8"
      "br-sao"  = "r042-7248c88b-ddb9-444f-be8d-7e88e103474b"
      "jp-osa"  = "r034-6c62587c-bb15-4ec3-acd8-27ab3517ce11"
      "eu-gb"   = "r018-c6bd891e-b3e0-41a4-81a8-51e09a4de45e"
      "eu-de"   = "r010-77158392-d53e-45a6-92ca-ae982ba299c9"
      "us-south"= "r006-9275f367-b656-408e-89f2-a64e9dcbbdae"
    }
  }
}
