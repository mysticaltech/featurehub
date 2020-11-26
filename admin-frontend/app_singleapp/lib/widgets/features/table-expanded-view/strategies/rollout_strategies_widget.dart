import 'package:app_singleapp/widgets/common/fh_outline_button.dart';
import 'package:app_singleapp/widgets/features/table-expanded-view/custom_strategy_attributes_bloc.dart';
import 'package:bloc_provider/bloc_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mrapi/api.dart';

import 'add_attribute_strategy_widget.dart';

class RolloutStrategiesWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bloc = BlocProvider.of<IndividualStrategyBloc>(context);

    return Column(children: [
      StreamBuilder<List<RolloutStrategyAttribute>>(
          stream: bloc.attributes,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data.isNotEmpty) {
              return Column(children: [
                for (var rolloutStrategyAttribute in snapshot.data)
                  AttributeStrategyWidget(attribute: rolloutStrategyAttribute,
                    attributeIsFirst: rolloutStrategyAttribute == snapshot.data.first,
                  bloc: bloc)
              ]);
            } else {
              return Container();
            }
          }),
      SizedBox(height: 16.0,),
      Row(
        children: [
          Text('Add rule', style: Theme.of(context).textTheme.caption),
          for (var e in StrategyAttributeWellKnownNames.values)
            if(e != StrategyAttributeWellKnownNames.session) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: FHOutlineButton(
                  onPressed: () => bloc.createAttribute(type: e),
                  title: '+ ${e.name}'),
            ),
        ],
      ),
      Row(
        children: [
          Text('Add custom rule', style: Theme.of(context).textTheme.caption),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: FHOutlineButton(
                onPressed: () => bloc.createAttribute(),
                title:
                '+ Custom'),
          ),
        ],
      ),
    ]);
  }
}
