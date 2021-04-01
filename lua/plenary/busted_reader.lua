BustedOutputReader = {}

  local spec_results = {}
  local current_spec = {}

  local function set_spec_status(line, find_str, status_str)
    if line:find(find_str) then
      current_spec.status = status_str
      return true
    end
  end

  local is_spec_result
  local cat_line

  local function reset()
    current_spec, cat_line, is_spec_result = {}, nil, nil
  end

  BustedOutputReader.output_to_table = function(...)

    for _, line in pairs({...}) do

      if is_spec_result then

        if line:find('{ENDOFSPEC}') then
          current_spec.content = cat_line
          table.insert(spec_results, current_spec)

          reset()
        else
          if not cat_line then cat_line = "" end
          cat_line = cat_line .. line .. '\n'
        end
      end

      if not is_spec_result then
        is_spec_result = set_spec_status(line, '{SPEC: FAIL}', 'failed') or
        set_spec_status(line, '{SPEC: ERROR}', 'error') or
        set_spec_status(line, '{SPEC: SUCCESS}', 'success') or
        set_spec_status(line, '{SPEC: PENDING}', 'pending')
      end
    end

  return spec_results
end

return BustedOutputReader

