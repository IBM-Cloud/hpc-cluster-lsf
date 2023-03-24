build {
  sources = ["source.ibmcloud-vpc.itself"]

  provisioner "file" {
    source = "/tmp/packages"
    destination = "/tmp/"
  }

  provisioner "shell" {
    execute_command = "{{.Vars}} bash '{{.Path}}'"
    script = "script.sh"
  }
}