output "communication_service" {
  value = data.azapi_resource.communication_service.output
}

output "role_assignments" {
  value = [
    for assignment in data.azapi_resource_list.role_assignments.output.assignments : assignment
    if lower(assignment.scope) == lower(var.resource_id)
  ]
}
