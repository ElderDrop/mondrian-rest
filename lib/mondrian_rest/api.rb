require_relative './api_helpers.rb'
require_relative './query_helper.rb'
require_relative './api_formatters.rb'

module Mondrian::REST

  class Api < Grape::API
    version '1', using: :header, vendor: 'openrafam'
    format :json

    helpers Mondrian::REST::APIHelpers
    helpers Mondrian::REST::QueryHelper

    resource :mdx do
      content_type :xls, "application/vnd.ms-excel"
      formatter :xls, Mondrian::REST::XLSFormatter
      content_type :html, "text/html"
      formatter :html, Mondrian::REST::HTMLFormatter
      desc "Execute an MDX query against a cube"
      content_type :txt, "text/plain"
      post do
        rbody = env['api.request.body']
        mdx(rbody)
      end
    end

    resource :cubes do
      desc "Returns the cubes defined in this server's schema"
      get do
        {
          'cubes' => olap.cube_names
        }
      end

      route_param :cube_name do
        desc "Return a cube"
        params do
          requires :cube_name, type: String, desc: "Cube name"
        end

        get do
          cube = get_cube_or_404(params[:cube_name])
          cube_def(cube)
        end

        resource :aggregate do
          content_type :xls, "application/vnd.ms-excel"
          formatter :xls, Mondrian::REST::XLSFormatter
          content_type :html, "text/html"
          formatter :html, Mondrian::REST::HTMLFormatter

          desc "aggregate from query parameters"
          params do
            optional :measures, type: Array
            optional :cut, type: Array, desc: "Specification of slicer axis"
            optional :drilldown, type: Array, desc: "Dimension(s) to be drilled down"
          end
          get do
            cube = get_cube_or_404(params[:cube_name])
            query = build_query(cube, params)
            mdx(query.to_mdx)
          end
        end

        resource :dimensions do
          route_param :dimension_name do
            desc "Return a dimension's members"
            params do
              requires :cube_name, type: String, desc: "Cube name"
              requires :dimension_name, type: String, desc: "Dimension name"
            end

            get do
              cube = get_cube_or_404(params[:cube_name])
              dimension = cube.dimension(params[:dimension_name])
              dimension.to_h
            end

            resource :levels do
              route_param :level_name do
                resource :members do
                  route_param :member_key,
                              type: String,
                              requirements: { member_key: /[a-z0-9\.\-\s]+/i } do
                    get do
                      cube = get_cube_or_404(params[:cube_name])
                      dimension = cube.dimension(params[:dimension_name])
                      level = dimension.hierarchies[0].level(params[:level_name])

                      member = level.members.detect { |m|
                        m.property_value('MEMBER_KEY').to_s == params[:member_key]
                      }
                      error!('member not found', 404) if member.nil?
                      member.to_h.merge({ancestors: member.ancestors.map(&:to_h)})
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end