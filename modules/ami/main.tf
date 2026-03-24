data "aws_ami" "llm" {
  most_recent = true
  filter {
    name   = "tag:Role"
    values = ["llm"]
  }
  filter {
    name   = "tag:Project"
    values = ["llm-test"]
  }
  owners = ["self"]
}

data "aws_ami" "bastion" {
  most_recent = true
  filter {
    name   = "tag:Role"
    values = ["bastion"]
  }
  filter {
    name   = "tag:Project"
    values = ["llm-test"]
  }
  owners = ["self"]
}

data "aws_ami" "monitoring" {
  most_recent = true
  filter {
    name   = "tag:Role"
    values = ["monitoring"]
  }
  filter {
    name   = "tag:Project"
    values = ["llm-test"]
  }
  owners = ["self"]
}

data "aws_ami" "database" {
  most_recent = true
  filter {
    name   = "tag:Role"
    values = ["database"]
  }
  filter {
    name   = "tag:Project"
    values = ["llm-test"]
  }
  owners = ["self"]
}
