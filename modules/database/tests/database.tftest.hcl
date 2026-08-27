mock_provider "aws" {
  # Mocked data sources return arbitrary strings by default, which fails
  # validation for anything that must be real JSON.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  project            = "cloudops"
  vpc_id             = "vpc-00000000000000000"
  private_subnet_ids = ["subnet-0000000000000000a", "subnet-0000000000000000b"]
}

run "dev_may_be_disposable" {
  command = plan

  variables {
    environment         = "dev"
    deletion_protection = false
    skip_final_snapshot = true
  }

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false
    error_message = "The database must never be reachable from the internet, in any environment."
  }

  assert {
    condition     = aws_db_instance.this.storage_encrypted
    error_message = "Storage encryption is required in every environment."
  }
}

run "prod_rejects_missing_deletion_protection" {
  command = plan

  variables {
    environment         = "prod"
    deletion_protection = false
    skip_final_snapshot = false
  }

  expect_failures = [aws_db_instance.this]
}

run "prod_rejects_skipping_the_final_snapshot" {
  command = plan

  variables {
    environment         = "prod"
    deletion_protection = true
    skip_final_snapshot = true
  }

  expect_failures = [aws_db_instance.this]
}

run "prod_rejects_short_backup_retention" {
  command = plan

  variables {
    environment             = "prod"
    deletion_protection     = true
    skip_final_snapshot     = false
    backup_retention_period = 1
  }

  expect_failures = [aws_db_instance.this]
}

run "prod_accepts_a_safe_configuration" {
  command = plan

  variables {
    environment             = "prod"
    deletion_protection     = true
    skip_final_snapshot     = false
    backup_retention_period = 7
    multi_az                = true
  }

  assert {
    condition     = aws_db_instance.this.multi_az
    error_message = "Production should run multi-AZ."
  }
}

run "no_ingress_rule_exists_until_a_client_is_allowed" {
  command = plan

  variables {
    environment                = "dev"
    allowed_security_group_ids = []
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.db) == 0
    error_message = "An empty allow-list must produce zero ingress rules, not an open group."
  }
}
