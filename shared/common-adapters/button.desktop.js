/* @flow */

import React, {Component} from 'react'
import {FlatButton} from 'material-ui'
import ProgressIndicator from './progress-indicator'
import {globalStyles, globalColors} from '../styles/style-guide'
import type {Props} from './button'

class Button extends Component {
  props: Props;

  _styles (type: Props.type): Object {
    let backgroundStyle = {}
    let labelStyle = {}
    let progressColor = globalColors.white

    const disabled = this.props.disabled || this.props.waiting

    switch (this.props.type) {
      case 'Primary':
        backgroundStyle = {
          ...stylesButtonPrimary,
          opacity: disabled ? stylesButtonPrimary.disabledOpacity : 1
        }
        break
      case 'Follow':
        backgroundStyle = {
          ...stylesButtonFollow,
          opacity: disabled ? stylesButtonFollow.disabledOpacity : 1
        }
        break
      case 'Following':
        backgroundStyle = {
          ...stylesButtonFollowing,
          opacity: disabled ? stylesButtonFollowing.disabledOpacity : 1
        }
        labelStyle = {
          color: globalColors.green
        }
        progressColor = globalColors.black_75
        break
      case 'Unfollow':
        backgroundStyle = {
          ...stylesButtonUnfollow,
          opacity: disabled ? stylesButtonUnfollow.disabledOpacity : 1
        }
        break
      case 'Danger':
        backgroundStyle = {
          ...stylesButtonDanger,
          opacity: disabled ? stylesButtonDanger.disabledOpacity : 1
        }
        break
      case 'Secondary':
      default:
        backgroundStyle = {
          ...stylesButtonSecondary,
          backgroundColor: this.props.backgroundMode === 'Terminal' ? globalColors.blue_30 : stylesButtonSecondary.backgroundColor,
          opacity: disabled ? stylesButtonSecondary.disabledOpacity : 1
        }
        labelStyle = {
          color: this.props.backgroundMode === 'Terminal' ? globalColors.white : globalColors.black_75
        }
        progressColor = globalColors.black_75
    }
    return {backgroundStyle, labelStyle, progressColor}
  }

  render () {
    // First apply styles for the main button types.
    let {backgroundStyle, labelStyle, progressColor} = this._styles(this.props.type)
    let smallStyle = {}

    // Then some overrides that apply to all button types.
    if (this.props.small) {
      smallStyle = stylesButtonSmall
      labelStyle = {
        ...labelStyle,
        ...stylesButtonSmallLabel
      }
    }

    if (this.props.waiting) {
      labelStyle = {
        ...labelStyle,
        opacity: 0
      }
    }

    let outerStyle = {position: 'relative'}
    if (this.props.style) {
      outerStyle = {...outerStyle, alignSelf: this.props.style.alignSelf}
    }

    if (this.props.fullWidth) {
        // Using minWidth here means we can't have a full-width button on the
        // same line/row as another button, the right thing is very unlikely to
        // happen.  The alternative is 'flex: 1' here, which would work but is
        // dangerous, because we'd be modifying our container.
        //
        // So let's just say that a fullWidth button can't have siblings.
      outerStyle = {...outerStyle, minWidth: '100%'}
      backgroundStyle = {...backgroundStyle, minWidth: '100%', height: 38}
    }

    if (this.props.waiting) {
      outerStyle = {...outerStyle, cursor: 'wait'}
    }

    let label = this.props.label

    if (this.props.more) {
      label = '•••'
    }

    return (
      <div style={outerStyle}>
        <FlatButton
          onClick={this.props.onClick}
          style={{...backgroundStyle, ...smallStyle, ...this.props.style}}
          labelStyle={{...stylesButtonLabel, ...labelStyle, ...this.props.labelStyle}}
          label={label}
          primary={this.props.type === 'Primary'}
          secondary={this.props.type === 'Secondary'}
          disabled={this.props.disabled || this.props.waiting}>
          {this.props.waiting && (
            <ProgressIndicator
              white={progressColor === globalColors.white}
              style={{...stylesProgress}}
            />)}
        </FlatButton>
      </div>
    )
  }
}

const buttonCommon = {
  ...globalStyles.fontSemibold,
  color: globalColors.white,
  whiteSpace: 'nowrap',
  borderRadius: 55,
  fontSize: 16,
  height: 32,
  lineHeight: '24px',
  textTransform: 'none',
  minWidth: 10
}

const stylesButtonPrimary = {
  ...buttonCommon,
  backgroundColor: globalColors.blue,
  disabledOpacity: 0.2
}
const stylesButtonSecondary = {
  ...buttonCommon,
  backgroundColor: globalColors.lightGrey2,
  disabledOpacity: 0.3,
  marginRight: 10
}
const stylesButtonDanger = {
  ...buttonCommon,
  backgroundColor: globalColors.red,
  disabledOpacity: 0.2,
  marginRight: 10
}
const stylesButtonFollow = {
  ...buttonCommon,
  backgroundColor: globalColors.green,
  disabledOpacity: 0.3,
  marginRight: 10,
  minWidth: 125
}
const stylesButtonFollowing = {
  ...buttonCommon,
  backgroundColor: globalColors.white,
  border: `solid 2px ${globalColors.green}`,
  marginRight: 10,
  minWidth: 125
}
const stylesButtonUnfollow = {
  ...buttonCommon,
  backgroundColor: globalColors.blue,
  disabledOpacity: 0.2,
  marginRight: 10,
  minWidth: 125
}
const stylesButtonSmall = {
  height: 28,
  lineHeight: '24px'
}
const stylesButtonLabel = {
  paddingLeft: 25,
  paddingRight: 25
}
const stylesButtonSmallLabel = {
  ...globalStyles.fontRegular,
  paddingLeft: 20,
  paddingRight: 20
}
const stylesProgress = {
  position: 'absolute',
  height: 'calc(100% - 4px)',
  left: 0,
  right: 0,
  top: 0,
  bottom: 0,
  margin: 'auto'
}

export default Button
